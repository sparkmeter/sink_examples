defmodule SimpleClient.SinkInstanceId do
  @moduledoc """
  Track the client and server instance ids.

  There should only ever be one record in this table.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  schema "sink_instance_ids" do
    field(:client_instance_id, :integer)
    field(:server_instance_id, :integer)

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = instance_id, params) do
    instance_id
    |> cast(params, [:client_instance_id, :server_instance_id])
    |> validate_required([:client_instance_id])
  end
end
