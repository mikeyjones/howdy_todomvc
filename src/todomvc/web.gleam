import gleam/int
import gleam/string
import gleam/result
import gleam/list
import gleam/option.{None, Some}
import gleam/bit_builder.{BitBuilder}
import gleam/http.{Http}
import gleam/http/response.{Response}
import gleam/http/cookie
import howdy/context.{Context}
import todomvc/error.{AppError}

pub fn escape(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
}

pub fn get_user_id(context: Context(a)) -> Result(Int, AppError) {
  case context.user {
    Some(user) ->
      int.parse(user.name)
      |> result.map_error(fn(_) { error.UserNotFound })

    None -> Error(error.UserNotFound)
  }
}

pub fn result_to_response(result: Result(Response(BitBuilder), AppError)) {
  case result {
    Ok(response) -> response
    Error(error) -> error_to_response(error)
  }
}

/// Return an appropriate HTTP response for a given error.
///
pub fn error_to_response(error: AppError) {
  case error {
    error.UserNotFound -> user_not_found()
    error.NotFound -> not_found()
    error.MethodNotAllowed -> method_not_allowed()
    error.BadRequest -> bad_request()
    error.UnprocessableEntity | error.ContentRequired -> unprocessable_entity()
    error.PgoError(_) | error.CreatingTodo -> internal_server_error()
  }
}

pub fn not_found() -> Response(BitBuilder) {
  let body = bit_builder.from_string("There's nothing here...")
  response.new(404)
  |> response.set_body(body)
}

pub fn user_not_found() -> Response(BitBuilder) {
  let attributes =
    cookie.Attributes(..cookie.defaults(Http), max_age: option.Some(0))
  not_found()
  |> response.set_cookie("uid", "", attributes)
}

pub fn method_not_allowed() -> Response(BitBuilder) {
  let body = bit_builder.from_string("There's nothing here...")
  response.new(405)
  |> response.set_body(body)
}

pub fn bad_request() -> Response(BitBuilder) {
  let body = bit_builder.from_string("Bad request")
  response.new(400)
  |> response.set_body(body)
}

pub fn internal_server_error() -> Response(BitBuilder) {
  let body = bit_builder.from_string("Internal server error. Sorry!")
  response.new(500)
  |> response.set_body(body)
}

pub fn unprocessable_entity() -> Response(BitBuilder) {
  let body = bit_builder.from_string("Unprocessable entity")
  response.new(422)
  |> response.set_body(body)
}

pub fn key_find(list: List(#(k, v)), key: k) -> Result(v, AppError) {
  list
  |> list.key_find(key)
  |> result.replace_error(error.UnprocessableEntity)
}

pub fn parse_int(string: String) -> Result(Int, AppError) {
  string
  |> int.parse
  |> result.replace_error(error.BadRequest)
}
