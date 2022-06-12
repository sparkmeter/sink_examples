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
end
