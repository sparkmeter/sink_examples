defmodule SimpleClient.SinkConfig do
  @moduledoc """
  Manages configuration of the Sink connection.
  """
  alias SimpleClient.{Repo, SinkInstanceId}

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

  @instance_id_primary_key 1

  def port, do: @sink_port

  def host, do: @sink_host

  def ssl_opts, do: @sink_ssl_opts

  @doc """
  Generate an instance ID and save it to the database.
  """
  def init_client_instance_id(client_instance_id \\ System.os_time(:second)) do
    {:ok, _} =
      %SinkInstanceId{id: @instance_id_primary_key}
      |> SinkInstanceId.changeset(%{client_instance_id: client_instance_id})
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:id])

    :ok
  end

  @doc """
  Load the client and server instance IDs from the database.
  """
  def get_instance_ids() do
    with %{client_instance_id: client, server_instance_id: server} <-
           Repo.get(SinkInstanceId, @instance_id_primary_key) do
      %{client: client, server: server}
    end
  end

  @doc """
  Set the server instance ID.
  """
  def set_server_instance_id(server_instance_id) do
    {:ok, _} =
      SinkInstanceId
      |> Repo.get(@instance_id_primary_key)
      |> case do
        %SinkInstanceId{} = instance ->
          instance
          |> SinkInstanceId.changeset(%{server_instance_id: server_instance_id})
          |> Repo.update()
      end

    :ok
  end
end
