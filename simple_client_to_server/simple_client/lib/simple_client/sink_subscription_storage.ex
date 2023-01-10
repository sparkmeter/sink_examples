defmodule SimpleClient.SinkSubscriptionStorage do
  import Ecto.Query, only: [from: 2]
  alias SimpleClient.Repo
  alias SimpleClient.GroundEventLog

  def queue_size(_subscription_name, "self", _client_instance_id, last_acked_seq_number) do
    query = from(g in GroundEventLog, where: g.id > ^last_acked_seq_number)
    Repo.aggregate(query, :count, :id)
  end

  def get_latest_ackd_subscription(_processor) do
    # todo: implement
    nil
  end

  def get_oldest_nackd_subscription(_processor) do
    # todo: implement
    nil
  end
end
