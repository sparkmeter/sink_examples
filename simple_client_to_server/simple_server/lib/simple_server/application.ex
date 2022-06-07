defmodule SimpleServer.Application do
  @moduledoc false

  use Application
  alias SimpleServer.SinkHandler
  require Logger

  @sink_port 2020

  @impl Application
  def start(_type, _args) do
    children = [
      {Sink.Connection.ServerListener,
       port: @sink_port, ssl_opts: sink_ssl_opts(), handler: SinkHandler}
    ]

    opts = [strategy: :one_for_one, name: SimpleServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def sink_ssl_opts do
    verify_fun = fn
      # Ignore expired certs and unknown CA
      _cert, {:bad_cert, :unknown_ca}, user_state -> {:valid, user_state}
      _cert, {:bad_cert, :cert_expired}, user_state -> {:valid, user_state}
      # Default taken from the erlang docs for `:verify_peer`
      _cert, {:bad_cert, _} = reason, _ -> {:fail, reason}
      _cert, {:extension, _}, user_state -> {:unknown, user_state}
      _cert, :valid, user_state -> {:valid, user_state}
      _cert, :valid_peer, user_state -> {:valid, user_state}
    end

    [
      certfile: "priv/certs/sink-examples-simple-server-cert.pem",
      keyfile: "priv/certs/sink-examples-simple-server-key.pem",
      #      cacertfile: "priv/certs/sink-examples-ca-cert.pem",
      secure_renegotiate: true,
      reuse_sessions: true,
      verify: :verify_peer,
      fail_if_no_peer_cert: false,
      verify_fun: {verify_fun, []}
    ]
  end
end
