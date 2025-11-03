defmodule MailSense.HTTPClient do
  @moduledoc false

  @type resp :: {:ok, %{status: pos_integer(), body: any()}} | {:error, term()}

  @callback get(String.t(), keyword()) :: resp
  @callback post(String.t(), any(), keyword()) :: resp
end
