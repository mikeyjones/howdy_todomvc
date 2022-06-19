import gleam/result
import gleam/string
import gleam/string_builder.{StringBuilder}
import todomvc/error
import todomvc/configuration.{Config}
import todomvc/item.{Category, Item}
import todomvc/templates/home as home_template
import todomvc/templates/item_created as item_created_template
import todomvc/templates/item as item_template
import todomvc/templates/item_changed as item_changed_template
import todomvc/templates/completed_cleared as completed_cleared_template
import todomvc/web
import todomvc/error.{AppError}
import howdy/response
import howdy/mime
import howdy/context.{Context}
import howdy/context/header
import howdy/context/url
import howdy/context/body

pub fn home(context: Context(Config), category: Category) {
  try user_id = web.get_user_id(context)
  let db = context.config.db_connection

  let items = case category == item.All {
    True -> item.list_items(user_id, db)
    False -> item.filtered_items(user_id, category == item.Completed, db)
  }
  let counts = item.get_counts(user_id, db)
  home_template.render_builder(items, counts, category)
  |> of_html()
  |> Ok
}

fn get_content(context: Context(Config)) {
  try content_items =
    body.get_form(context)
    |> result.replace_error(error.BadRequest)
  web.key_find(content_items, "content")
}

fn do_add_todo(context: Context(Config), user_id, db) {
  try content = get_content(context)
  try id = item.insert_item(content, user_id, db)
  Ok(Item(id: id, completed: False, content: content))
}

pub fn add_todo(context: Context(Config)) {
  let db = context.config.db_connection
  try user_id = web.get_user_id(context)
  try new_item = do_add_todo(context, user_id, db)
  let counts = item.get_counts(user_id, db)
  let display = item.is_member(new_item, current_category(context))

  item_created_template.render_builder(new_item, counts, display)
  |> of_html()
  |> Ok
}

pub fn delete_todo(context: Context(Config)) {
  let db = context.config.db_connection
  try id = get_int_from_url(context, "id")
  try user_id = web.get_user_id(context)
  item.delete_item(id, user_id, db)
  response.of_string("")
  |> Ok
}

pub fn delete_todos(context: Context(Config)) {
  let db = context.config.db_connection
  try user_id = web.get_user_id(context)
  item.delete_completed(user_id, db)
  let counts = item.get_counts(user_id, db)
  let items = case current_category(context) {
    item.All | item.Active -> item.list_items(user_id, db)
    item.Completed -> []
  }

  completed_cleared_template.render_builder(items, counts)
  |> of_html()
  |> Ok
}

pub fn get_todo_edit_form(context: Context(Config)) {
  let db = context.config.db_connection
  try id = get_int_from_url(context, "id")
  try user_id = web.get_user_id(context)
  try item = item.get_item(id, user_id, db)

  item_template.render_builder(item, True)
  |> of_html
  |> Ok
}

pub fn update_todo(context: Context(Config)) {
  let db = context.config.db_connection
  try id = get_int_from_url(context, "id")
  try user_id = web.get_user_id(context)
  try content = get_content(context)
  try updated_item = item.update_item(id, user_id, content, db)
  item_template.render_builder(updated_item, False)
  |> of_html()
  |> Ok
}

pub fn item_completion(context: Context(Config)) {
  let db = context.config.db_connection
  try id = get_int_from_url(context, "id")
  try user_id = web.get_user_id(context)
  try item = item.toggle_completion(id, user_id, db)
  let counts = item.get_counts(user_id, db)
  let display = item.is_member(item, current_category(context))

  item_changed_template.render_builder(item, counts, display)
  |> of_html()
  |> Ok
}

fn current_category(context) -> Category {
  let current_url =
    header.get_value(context, "hx-current-url")
    |> result.unwrap("")
  case string.contains(current_url, "/active") {
    True -> item.Active
    False ->
      case string.contains(current_url, "/completed") {
        True -> item.Completed
        False -> item.All
      }
  }
}

fn get_int_from_url(
  context: Context(Config),
  key: String,
) -> Result(Int, AppError) {
  url.get_int(context, key)
  |> result.map_error(fn(_) { error.UnprocessableEntity })
}

fn of_html(html: StringBuilder) {
  html
  |> string_builder.to_string()
  |> response.of_string()
  |> response.with_content_type(mime.from_extention("html"))
}
