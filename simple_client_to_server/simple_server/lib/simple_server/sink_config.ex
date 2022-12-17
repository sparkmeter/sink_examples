defmodule SimpleServer.SinkConfig do
  @moduledoc """
  Manages configuration of the Sink connections.
  """
  alias SimpleServer.{Repo, SinkInstanceId}

  @sink_port 2020
  @self_id "self"

  def port, do: @sink_port

  def ssl_opts do
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

  @doc """
  Generate an instance ID and save it to the database.
  """
  def init_server_instance_id(instance_id \\ System.os_time(:second)) do
    insert_instance_id(@self_id, instance_id, :nothing)
  end

  @doc """
  Load the client and server instance IDs from the database.
  """
  def get_instance_ids(client_id) do
    client_instance_id =
      with %SinkInstanceId{instance_id: i} <- Repo.get(SinkInstanceId, client_id), do: i

    s = Repo.get!(SinkInstanceId, @self_id)
    %{client: client_instance_id, server: s.instance_id}
  end

  @doc """
  Set the client instance ID.
  """
  def set_client_instance_id(id, instance_id) do
    insert_instance_id(id, instance_id, set: [instance_id: instance_id])
  end

  def client_configuration(client_id) do
    {:ok, get_instance_ids(client_id)}
  end

  defp insert_instance_id(id, instance_id, on_conflict) do
    {:ok, _} =
      %SinkInstanceId{id: id}
      |> SinkInstanceId.changeset(%{instance_id: instance_id})
      |> Repo.insert(on_conflict: on_conflict, conflict_target: [:id])

    {:ok, instance_id}
  end
end
