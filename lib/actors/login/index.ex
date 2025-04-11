defmodule Actors.Login do
  use GenServer

  defp init_state(client, bridge_actor) do
    %{
      behavior: :menu,
      client: client,
      bridge_actor: bridge_actor
    }
  end

  def start_link(client, bridge_actor) do
    IO.puts("Actor.Login start_link")

    GenServer.start_link(__MODULE__, init_state(client, bridge_actor))
  end

  # PRINT MESSAGES
  @impl true
  def handle_cast({:message, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.message(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:warning, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.warning(msg))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:success, msg}, %{client: client} = state) do
    :gen_tcp.send(client, Messages.success(msg))
    {:noreply, state}
  end

  # STOP
  @impl true
  def handle_cast({:stop}, %{name: n} = state) do
    Actors.TableManager.player_stop(n)
    {:stop, :normal, state}
  end

  # STATE - MENU
  @impl true
  def handle_cast({:recv, data}, %{behavior: :menu} = state) do
    case Actors.Login.Regex.check_menu_input(data) do
      {:ok, :sign_in} ->
        GenServer.cast(self(), {:warning, Actors.Login.Messages.sign_in()})
        {:noreply, %{state | behavior: :sign_in}}

      {:ok, :sign_up} ->
        GenServer.cast(self(), {:warning, Actors.Login.Messages.sign_up()})
        {:noreply, %{state | behavior: :sign_up}}

      {:error, :invalid_input} ->
        GenServer.cast(self(), {:warning, Actors.Login.Messages.menu_invalid_input()})
        {:noreply, state}
    end
  end

  # STATE - SIGN IN
  @impl true
  def handle_cast({:recv, data}, %{bridge_actor: bridge_actor, behavior: :sign_in} = state) do
    case Actors.Login.Regex.check_username_and_password(data) do
      {:ok, name, password} ->
        GenServer.cast(bridge_actor, {:goto_game})
        {:stop, :normal, state}

      {:error, :invalid_input} ->
        GenServer.cast(self(), {:warning, Actors.Login.Messages.sign_in() <> "\n\n" <> Actors.Login.Messages.menu_invalid_input()})
        {:noreply, state}
    end
  end

  # STATE - SIGN UP
  @impl true
  def handle_cast({:recv, data}, %{bridge_actor: bridge_actor, behavior: :sign_up} = state) do
    case Actors.Login.Regex.check_username_and_password(data) do
      {:ok, name, password} ->
        GenServer.cast(bridge_actor, {:goto_game})
        {:stop, :normal, state}

      {:error, :invalid_input} ->
        GenServer.cast(self(), {:warning, Actors.Login.Messages.sign_up() <> "\n\n" <> Actors.Login.Messages.menu_invalid_input()})
        {:noreply, state}
    end
  end

  # DEGUB that march everything
  def handle_cast({x, _}, state) do
    IO.inspect("Receiced " <> inspect(x) <> " behavior" <> inspect(state[:behavior]))

    {:noreply, state}
  end

  # - - -

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end
end
