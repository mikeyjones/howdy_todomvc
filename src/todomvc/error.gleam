import gleam/pgo

pub type AppError {
  NotFound
  UserNotFound
  BadRequest
  UnprocessableEntity
  ContentRequired
  MethodNotAllowed
  CreatingTodo
  PgoError(pgo.QueryError)
}
