defmodule SimpleClient.Application do
  @moduledoc false

  use Application

  alias SimpleClient.{Repo, OutgoingEventPoller, SinkHandler}

  @sink_port 2020
  @sink_host "localhost"
  # this is for example purposes only, do something more secure with your setup
  @sink_ssl_opts [
    certfile: "priv/certs/sink-examples-simple-client-cert.pem",
    keyfile: "priv/certs/sink-examples-simple-client-key.pem",
    cacertfile: "priv/certs/sink-examples-ca-cert.pem",
    secure_renegotiate: true,
    reuse_sessions: true,
    verify: :verify_peer,
    fail_if_no_peer_cert: true
  ]

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

    result
  end

  # don't run the client in tests
  defp sink_client(:test), do: []

  defp sink_client(_) do
    [
      {Sink.Connection.Client,
       port: @sink_port, host: @sink_host, ssl_opts: @sink_ssl_opts, handler: SinkHandler}
    ]
  end
end
