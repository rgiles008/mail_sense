defmodule MailSense.Mail.Unsubscribe do
  alias MailSense.Mail.GmailClient

  @req_opts [
    follow_redirects: true,
    max_redirects: 5,
    receive_timeout: 8_000,
    connect_timeout: 5_000
  ]

  @doc """
  Unsubscribes using links parsed from headers/body.

  Accepts:
    - links: %{http: url} and/or %{mailto: address}
    - headers: raw headers map (to detect RFC 8058 one-click)

  Returns:
    {:ok, :one_click_post | :http_get | :mailto} | {:error, reason}
  """
  def do_unsubscribe(conn, user_email, links, headers \\ %{})

  # RFC 8058 one-click: prefer HTTP path first when present.
  def do_unsubscribe(_conn, _user_email, %{http: url} = _links, headers) when is_binary(url) do
    case String.downcase(Map.get(headers, "List-Unsubscribe-Post", "")) do
      "list-unsubscribe=one-click" ->
        case Req.post(url, @req_opts) do
          {:ok, _} -> {:ok, :one_click_post}
          {:error, reason} -> {:error, {:http_post_failed, reason}}
        end

      _ ->
        case Req.get(url, @req_opts) do
          {:ok, _} -> {:ok, :http_get}
          {:error, reason} -> {:error, {:http_get_failed, reason}}
        end
    end
  end

  # mailto fallback (your original logic)
  def do_unsubscribe(conn, user_email, %{mailto: mailto} = _links, _headers)
      when is_binary(mailto) do
    raw = """
    From: #{user_email}
    To: #{String.trim_leading(mailto, "mailto:")}
    Subject: Unsubscribe
    Date: #{rfc2822_now()}

    Please unsubscribe me.
    """

    raw64 =
      raw
      |> Base.encode64()
      |> String.replace("+", "-")
      |> String.replace("/", "_")

    case GmailClient.send_raw(conn, user_email, raw64) do
      {:ok, _} -> {:ok, :mailto}
      {:error, reason} -> {:error, {:mailto_failed, reason}}
    end
  end

  # no links available
  def do_unsubscribe(_conn, _user_email, _links, _headers), do: {:error, :no_unsubscribe}

  defp rfc2822_now(), do: Calendar.strftime(DateTime.utc_now(), "%a, %d %b %Y %H:%M:%S +0000")
end
