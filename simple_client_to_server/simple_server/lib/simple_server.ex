defmodule SimpleServer do
  @moduledoc false
  def load_authenticated_clients do
    [
      {"priv/certs/sink-examples-simple-client-cert.pem", "example-client"}
    ]
    |> Enum.map(fn {cert_path, client_id} ->
      [{:Certificate, cert, _}] =
        cert_path
        |> File.read!()
        |> :public_key.pem_decode()

      {cert, client_id}
    end)
    |> Map.new()
  end

  def insert_ground_event({client_id, instance_id}, sink_event, ingested_at) do
    %SimpleServer.Ground.GroundEventLog{
      client_id: client_id,
      instance_id: instance_id,
      ingested_at: ingested_at,
      key: sink_event.key,
      event_type_id: sink_event.event_type_id,
      offset: sink_event.offset,
      event_timestamp: sink_event.timestamp,
      schema_version: sink_event.schema_version,
      event_data: sink_event.event_data
    }
    |> SimpleServer.Repo.insert()
  end
end
