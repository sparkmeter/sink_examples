defmodule SimpleClient.SinkSubscriptionStorage do
  import Ecto.Query, only: [from: 2]
  alias SimpleClient.Repo
  alias SimpleClient.GroundEventLog
  alias SimpleClient.OutgoingEventSubscription

  @log_table GroundEventLog
  @sub_table OutgoingEventSubscription

  def take(OutgoingEventSubscription, "self", _client_instance_id, last_seq_number, num) do
    last_seq_number = last_seq_number || 0

    from(log in @log_table,
      join: sub in @sub_table,
      on:
        log.key == sub.key and log.event_type_id == sub.event_type_id and
          log.offset > sub.consumer_offset,
      where: log.id > ^last_seq_number,
      select: log,
      order_by: [asc: log.id],
      limit: ^num
    )
    |> Repo.all()
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
