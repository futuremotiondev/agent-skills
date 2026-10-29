defmodule Shop.Cart do
  @moduledoc "Cart."

  @doc "Adds an item."
  def add(cart, item) do
    [item | cart]
  end

  def total(cart), do: Enum.sum(cart)

  defp secret(x) do
    fn y -> y + x end
  end
end
