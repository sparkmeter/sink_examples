defmodule SimpleClient.Application do
  @moduledoc false

  use Application

  alias SimpleClient.{Repo, OutgoingEventPoller, SinkConfig, SinkHandler}

  @impl Application
  def start(_type, _args) do
    env = Application.get_env(:simple_client, :env)

    children =
      [
        Repo,
        OutgoingEventPoller
      ] ++ sink_client(env)

    result =
      Supervisor.start_link(children, strategy: :one_for_one, name: SimpleClient.Supervisor)

    # note: this is bad practice since it could stop your startup
    :ok = SinkConfig.init_client_instance_id()

    result
  end

  # don't run the client in tests
  defp sink_client(:test), do: []

  defp sink_client(_) do
    [
      {Sink.Connection.Client,
       port: SinkConfig.port(),
       host: SinkConfig.host(),
       ssl_opts: SinkConfig.ssl_opts(),
       handler: SinkHandler}
    ]
  end
end
