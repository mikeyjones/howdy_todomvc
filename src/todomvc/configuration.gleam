import gleam/pgo

pub type Config {
  Config(db_connection: pgo.Connection)
}
