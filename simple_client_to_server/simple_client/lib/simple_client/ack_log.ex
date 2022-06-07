defmodule SimpleClient.AckLog do
  @moduledoc """
  A log of events that have been ACK'd by the server
  """
  use Ecto.Schema

  schema "ack_logs" do
    timestamps(updated_at: false)
  end
end
