import gleam/http.{Http}
import gleam/http/request.{Request}
import gleam/http/response as http_response
import gleam/http/cookie
import gleam/option.{Some}
import gleam/function.{compose}
import gleam/crypto
import gleam/list
import gleam/int
import howdy/router.{
  Delete, Get, Patch, Post, RouterMap, RouterMapWithFilters, Static,
}
import howdy/filter.{Filter}
import howdy/context.{Context}
import howdy/context/user.{User} as context_user
import todomvc/web
import todomvc/item.{Category}
import todomvc/user
import todomvc/configuration.{Config}
import todomvc/web/controller

pub fn routes(secret: String) {
  RouterMap(
    "/",
    [
      RouterMapWithFilters(
        "/",
        filters: [authenticate(_, secret)],
        routes: [
          Get("/", home_page(item.All)),
          Get("/active", home_page(item.Active)),
          Get("/completed", home_page(item.Completed)),
          Delete("/completed", delete_todos()),
          RouterMap(
            "/todos",
            [
              Post("/", add_todo()),
              Get("/{id:Int}", todo_edit_form()),
              Patch("/{id:Int}", update_todo()),
              Patch("/{id:Int}/completion", complete_todo()),
              Delete("/{id:Int}", delete_todo()),
            ],
          ),
        ],
      ),
      Static("/", "./priv/static"),
    ],
  )
}

fn home_page(category: Category) {
  compose(controller.home(_, category), web.result_to_response)
}

fn delete_todos() {
  compose(controller.delete_todos, web.result_to_response)
}

fn add_todo() {
  compose(controller.add_todo, web.result_to_response)
}

fn delete_todo() {
  compose(controller.delete_todo, web.result_to_response)
}

fn todo_edit_form() {
  compose(controller.get_todo_edit_form, web.result_to_response)
}

fn update_todo() {
  compose(controller.update_todo, web.result_to_response)
}

fn complete_todo() {
  compose(controller.item_completion, web.result_to_response)
}

fn authenticate(filter: Filter(Config), secret: String) {
  fn(context: Context(Config)) {
    let db = context.config.db_connection
    case user_id_from_cookies(context.request, secret) {
      Ok(user_id) ->
        set_user(context, user_id)
        |> filter()
      Error(_) -> {
        let user_id = user.insert_user(db)
        set_user(context, user_id)
        |> filter()
        |> http_response.set_cookie(
          "uid",
          encrypt_id(user_id, secret),
          cookie.defaults(Http),
        )
      }
    }
  }
}

fn set_user(context, id) {
  Context(..context, user: Some(User(name: int.to_string(id), claims: [])))
}

fn encrypt_id(id: Int, secret: String) {
  <<int.to_string(id):utf8>>
  |> crypto.sign_message(<<secret:utf8>>, crypto.Sha256)
}

fn user_id_from_cookies(request: Request(t), secret: String) -> Result(Int, Nil) {
  case list.key_find(request.get_cookies(request), "uid") {
    Ok(id) ->
      case user.verify_cookie_id(id, secret) {
        Ok(verified_cookie_id) -> Ok(verified_cookie_id)
        Error(_) -> Error(Nil)
      }
    //result.map(id, option.Some)
    Error(_) -> Error(Nil)
  }
}
