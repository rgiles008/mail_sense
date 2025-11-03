defmodule MailSense.HTTPReq do
  @behaviour MailSense.HTTPClient

  @impl true
  def get(url, opts \\ []) do
    # Avoid :connect_timeout; for Req 0.5.x you can use:
    #   receive_timeout: 5_000
    #   connect_options: [timeout: 5_000]
    Req.get(
      url: url,
      decode_json: true,
      receive_timeout: 5_000,
      connect_options: [timeout: 5_000]
    )
    |> normalize()
  end

  @impl true
  def post(url, body, opts \\ []) do
    Req.post(
      url: url,
      json: body,
      decode_json: true,
      receive_timeout: 5_000,
      connect_options: [timeout: 5_000]
    )
    |> normalize()
  end

  defp normalize({:ok, %Req.Response{} = r}), do: {:ok, %{status: r.status, body: r.body}}
  defp normalize({:error, _} = err), do: err
end
