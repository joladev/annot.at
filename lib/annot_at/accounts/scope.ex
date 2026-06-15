defmodule AnnotAt.Accounts.Scope do
  @moduledoc """
  The current authentication scope: the logged-in user, or nil for a guest.
  """

  alias AnnotAt.Accounts.User

  defstruct [:user]

  @type t :: %__MODULE__{user: User.t()}

  @spec for_user(User.t() | nil) :: t() | nil
  def for_user(%User{} = user), do: %__MODULE__{user: user}
  def for_user(nil), do: nil
end
