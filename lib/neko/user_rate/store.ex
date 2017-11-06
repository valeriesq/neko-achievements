defmodule Neko.UserRate.Store do
  @type user_rate_t :: %Neko.UserRate{}
  @type user_rates_t :: MapSet.t(user_rate_t)

  @ets_table :user_anime_ids

  @spec start_link() :: Agent.on_start
  def start_link do
    Agent.start_link(fn ->
      :ets.new(@ets_table, [:named_table, read_concurrency: true])
      MapSet.new()
    end)
  end

  @spec stop(pid) :: :ok
  def stop(pid) do
    Agent.stop(pid)
  end

  @spec reload(pid, pos_integer) :: :ok
  def reload(pid, user_id) do
    Agent.update(pid, fn _ ->
      user_rates = user_rates(user_id)
      on_set_user_rates(pid, user_rates)
      user_rates
    end)
  end

  @spec user_anime_ids(pid) :: MapSet.new(pos_integer)
  def user_anime_ids(pid) do
    case :ets.lookup(@ets_table, pid) do
      [{^pid, user_anime_ids}] -> user_anime_ids
      [] -> raise("no user anime ids for #{inspect(pid)}")
    end
  end

  @spec all(pid) :: user_rates_t
  def all(pid) do
    Agent.get(pid, &(&1))
  end

  @spec put(pid, user_rate_t) :: :ok
  def put(pid, user_rate) do
    Agent.update(pid, fn(x) ->
      on_put_user_rate(pid, user_rate)
      MapSet.put(x, user_rate)
    end)
  end

  @spec set(pid, user_rates_t) :: :ok
  def set(pid, user_rates) do
    Agent.update(pid, fn _ ->
      on_set_user_rates(pid, user_rates)
      user_rates
    end)
  end

  @spec delete(pid, user_rate_t) :: :ok
  def delete(pid, user_rate) do
    Agent.update(pid, fn(x) ->
      on_delete_user_rate(pid, user_rate)
      MapSet.delete(x, user_rate)
    end)
  end

  defp on_put_user_rate(pid, user_rate) do
    user_anime_ids =
      user_anime_ids(pid)
      |> MapSet.put(user_rate.target_id)
    :ets.insert(@ets_table, {pid, user_anime_ids})
  end
  defp on_set_user_rates(pid, user_rates) do
    user_anime_ids =
      user_rates
      |> Enum.map(&(&1.target_id))
      |> MapSet.new()
    :ets.insert(@ets_table, {pid, user_anime_ids})
  end
  defp on_delete_user_rate(pid, user_rate) do
    user_anime_ids =
      user_anime_ids(pid)
      |> MapSet.delete(user_rate.target_id)
    :ets.insert(@ets_table, {pid, user_anime_ids})
  end

  @spec user_rates(pos_integer) :: user_rates_t
  defp user_rates(user_id) do
    Neko.Shikimori.Client.get_user_rates!(user_id)
    |> MapSet.new()
  end
end
