defmodule EventQueues do
  @moduledoc """
  Modules and methods for managing queues of subscribed events from an event log
  """
  alias EventQueues.Coordinator
  alias EventQueues.QueueManager

  defdelegate add_client(subscription_name, client_id, client_instance_id), to: Coordinator
  defdelegate remove_client(subscription_name, client_id), to: Coordinator
  defdelegate take(subscription_name, client_id, num), to: QueueManager
end
