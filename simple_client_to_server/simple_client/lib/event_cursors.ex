defmodule EventCursors do
  @moduledoc """
  Modules and methods for managing cursors for subscribed events from an event log
  """
  alias EventCursors.Coordinator

  defdelegate add_client(subscription_name, client_id, client_instance_id), to: Coordinator
end
