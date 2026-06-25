defmodule AnnotAt.Atproto.TID do
  @moduledoc """
  atproto TID (timestamp identifier), frequenty used as record keys.

  https://atproto.com/specs/tid)
  """

  @alphabet "234567abcdefghijklmnopqrstuvwxyz"

  @spec now() :: String.t()
  def now(time \\ System) do
    # Shifts the time to make space for a random "clock ID" which basically
    # just means we wouldn't get collisions if two TIDs were generated the
    # same microsecond. Probably overkill.
    clock_id = :rand.uniform(1024) - 1
    shifted = time.os_time(:microsecond) * 1024
    timestamp = shifted + clock_id
    new(timestamp)
  end

  @spec at_time(DateTime.t()) :: String.t()
  def at_time(%DateTime{} = datetime) do
    clock_id = :rand.uniform(1024) - 1
    timestamp_μs = DateTime.to_unix(datetime, :microsecond) * 1024
    new(timestamp_μs + clock_id)
  end

  @spec new(non_neg_integer()) :: String.t()
  def new(int) do
    int
    |> Integer.digits(32)
    |> Enum.map_join(&<<:binary.at(@alphabet, &1)>>)
    |> String.pad_leading(13, "2")
  end
end
