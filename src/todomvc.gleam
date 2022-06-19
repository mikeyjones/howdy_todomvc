import gleam/erlang
import gleam/erlang/os
import gleam/int
import gleam/result
import gleam/option
import gleam/string
import gleam/pgo
import howdy/server
import todomvc/log
import todomvc/web/router
import todomvc/database
import todomvc/configuration.{Config}
import todomvc/log_requests

pub fn main() {
  log.configure_backend()

  let port = load_port()

  let db = start_database_connection_pool()
  assert Ok(_) = database.migrate_schema(db)

  let config = Config(db_connection: db)

  string.concat(["Listening on localhost:", int.to_string(port), " ✨"])
  |> log.info

  case server.start_with_port(
    port,
    load_application_secret()
    |> router.routes(),
    config,
  ) {
    Ok(pid) -> {
      server.register_middleware(
        pid,
        fn(middleware) {
          middleware
          |> log_requests.middleware()
        },
      )
      Nil
    }
    Error(_) -> log.info("server failed to start")
  }
  erlang.sleep_forever()
}

pub fn start_database_connection_pool() -> pgo.Connection {
  let config =
    os.get_env("DATABASE_URL")
    |> result.then(pgo.url_config)
    // In production we use IPv6
    |> result.map(fn(config) { pgo.Config(..config, ip_version: pgo.Ipv6) })
    |> result.lazy_unwrap(fn() {
      pgo.Config(
        ..pgo.default_config(),
        host: "localhost",
        database: "gleam_todomvc_dev",
        user: "postgres",
        password: option.Some("postgres"),
      )
    })

  pgo.connect(pgo.Config(..config, pool_size: 15))
}

fn load_port() -> Int {
  os.get_env("PORT")
  |> result.then(int.parse)
  |> result.unwrap(3000)
}

fn load_application_secret() -> String {
  os.get_env("APPLICATION_SECRET")
  |> result.unwrap("27434b28994f498182d459335258fb6e")
}
