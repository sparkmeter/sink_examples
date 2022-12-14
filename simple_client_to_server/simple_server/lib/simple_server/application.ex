defmodule SimpleServer.Application do
  @moduledoc false

  use Application
  alias SimpleServer.{Repo, SinkConfig, SinkHandler}
  require Logger

  @impl Application
  def start(_type, _args) do
    env = Application.get_env(:simple_server, :env)

    children =
      [
        Repo
      ] ++ sink_server(env)

    opts = [strategy: :one_for_one, name: SimpleServer.Supervisor]
    result = Supervisor.start_link(children, opts)

    # note: this is bad practice since it could stop your startup
    {:ok, _} = SinkConfig.init_server_instance_id()

    result
  end

  defp sink_server(:test), do: []

  defp sink_server(_) do
    [
      {Sink.Connection.ServerListener,
       port: SinkConfig.port(), ssl_opts: SinkConfig.ssl_opts(), handler: SinkHandler}
    ]
  end
end
