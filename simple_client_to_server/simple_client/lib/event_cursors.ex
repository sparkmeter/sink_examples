defmodule EventCursors do
  @moduledoc """
  Modules and methods for managing cursors for subscribed events from an event log
  """
  alias EventCursors.Coordinator
  alias EventCursors.CursorManager

  defdelegate add_client(subscription_name, client_id, client_instance_id), to: Coordinator
  defdelegate queue_size(subscription_name, client_id), to: CursorManager
end
