defmodule SimpleServer.IncomingEventProcessor do
  @moduledoc """
  Processes events async
  """
  use Broadway
  require Logger

  @producer_mod __MODULE__
  # @producer_mod Keyword.fetch!(:simple_server, :producer)

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {@producer_mod, 1}
        #        transformer: {Transformer, :transform, []}
      ],
      processors: [
        default: [concurrency: 1, max_demand: 20]
      ]
    )
  end

  @impl true
  def handle_message(:default, %{metadata: %{client: client}} = message, _context) do
    IO.puts("handling failed")
    Broadway.Message.put_batcher(message, client)
  end

  @impl true
  def handle_batch(:readings, messages, _info, _context) do
    IO.puts("handling batch")
    IO.inspect(messages)

    messages
  end

  @impl true
  def handle_failed(messages, _context) do
    IO.puts("handling failed")
    # todo: NACK

    messages
  end
end
