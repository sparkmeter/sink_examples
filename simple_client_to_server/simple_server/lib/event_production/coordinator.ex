defmodule EventProduction.Coordinator do
  @moduledoc """
  Coordinates starting and stopping event producer groups for a client_id
  """
  use GenServer
  alias EventProduction.EventProducer

  defmodule State do
    @moduledoc false

    defstruct [:event_producers]

    def init() do
      %State{
        event_producers: %{}
      }
    end

    def add_client(state, processor, client_id, pid, ref) do
      %State{
        state
        | event_producers: Map.put(state.event_producers, {processor, client_id}, {pid, ref})
      }
    end

    def registered?(state, processor, client_id) do
      Map.has_key?(state.event_producers, {processor, client_id})
    end
  end

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def add_client(processor, client_id) do
    GenServer.call(__MODULE__, {:add_client, processor, client_id})
  end

  @impl true
  def init(_) do
    {:ok, State.init()}
  end

  @impl true
  def handle_call({:add_client, processor, client_id}, _from, state) do
    if !registered?(state, processor, client_id) do
      {:ok, pid} =
        DynamicSupervisor.start_child(
          EventProduction.DynamicSupervisor,
          {EventProducer, [processor: processor, client_id: client_id]}
        )

      ref = Process.monitor(pid)
      new_state = State.add_client(state, processor, client_id, pid, ref)
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :in_use}, state}
    end
  end

  defp registered?(state, processor, client_id) do
    # todo: also use global lock and/or postgres locks or something to ensure global uniquess
    State.registered?(state, processor, client_id)
  end
end
