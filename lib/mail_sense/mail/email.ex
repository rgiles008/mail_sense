defmodule MailSense.Mail.Email do
  use Ecto.Schema
  import Ecto.Changeset

  alias MailSense.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "emails" do
    field :gmail_message_id, :string
    field :thread_id, :string
    field :subject, :string
    field :from, :string
    field :to, :string
    field :snippet, :string
    field :internal_date, :integer
    field :ai_summary, :string
    field :ai_category_reason, :string
    field :raw_headers, :map
    field :list_unsubscribe, :map
    field :archived_at, :utc_datetime
    field :body_text, :string
    field :body_html, :string
    field :unsubscribe_status, :string, default: "none"
    field :unsubscribed_at, :utc_datetime
    field :unsubscribe_error, :string
    field :last_unsubscribe_attempt_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :gmail_account, MailSense.Accounts.GmailAccount
    belongs_to :category, MailSense.Mail.Category

    timestamps()
  end

  def changeset(email, attrs) do
    email
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:gmail_account_id, :gmail_message_id])
    |> unique_constraint(:gmail_message_id)
  end

  def extract_unsubscribe_links(headers \\ %{}, body_text \\ %{}) do
    headers = headers || %{}
    list_header = headers["List-Unsubscribe"]

    from_hdr =
      case list_header do
        nil ->
          %{}

        raw ->
          links =
            Regex.scan(~r/<([^>]+)>|([^,\s<>]+)/, raw)
            |> Enum.map(fn [_, a, b] -> a || b end)
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))

          %{
            http: Enum.find(links, &String.starts_with?(&1, "http")),
            mailto: Enum.find(links, &String.starts_with?(&1, "mailto:"))
          }
      end

    from_body =
      (body_text || "")
      |> find_unsubscribe_in_body()

    Map.merge(from_hdr, from_body, fn _key, val1, val2 -> val1 || val2 end)
  end

  def mark_unsubscribe_queued!(email) do
    change(email,
      unsubscribe_status: "queued",
      last_unsubscribe_attempt_at: DateTime.utc_now(),
      unsubscribe_error: nil
    )
    |> Repo.update!()
  end

  @doc """
  Mark email as successfully unsubscribed.
  """
  def mark_unsubscribed!(email) do
    change(email,
      unsubscribe_status: "success",
      unsubscribed_at: DateTime.utc_now(),
      unsubscribe_error: nil
    )
    |> Repo.update!()
  end

  @doc """
  Mark email as failed to unsubscribe; store reason.
  """
  def mark_unsubscribe_failed!(email, reason) do
    change(email,
      unsubscribe_status: "failed",
      last_unsubscribe_attempt_at: DateTime.utc_now(),
      unsubscribe_error: format_reason(reason)
    )
    |> Repo.update!()
  end

  defp format_reason(%{reason: r}), do: to_string(r)
  defp format_reason({:error, r}), do: to_string(r)
  defp format_reason(r), do: to_string(r)

  def parse_gmail_message(%GoogleApi.Gmail.V1.Model.Message{
        payload: payload,
        snippet: sn,
        id: id,
        threadId: tid,
        internalDate: int_dt
      }) do
    {hdrs, unsub} = extract_headers(payload.headers || [])
    {text, html} = extract_body(payload)

    %{
      gmail_message_id: id,
      thread_id: tid,
      subject: Map.get(hdrs, "Subject"),
      from: Map.get(hdrs, "From"),
      to: Map.get(hdrs, "To"),
      snippet: sn,
      internal_date: String.to_integer(int_dt || "0"),
      raw_headers: hdrs,
      list_unsubscribe: unsub,
      body_text: text,
      body_html: html
    }
  end

  defp find_unsubscribe_in_body(text) do
    http =
      Regex.run(~r/(https?:\/\/[^\s"']*unsubscribe[^\s"']*)/i, text, capture: :all_but_first)
      |> case do
        [url | _] -> url
        _ -> nil
      end

    mailto =
      Regex.run(~r/(mailto:[^\s"']*unsubscribe[^\s"']*)/i, text, capture: :all_but_first)
      |> case do
        [m | _] -> m
        _ -> nil
      end

    %{http: http, mailto: mailto}
  end

  def mark_deleted!(email) do
    email
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now())
    |> Repo.update!()
  end

  def mark_deleted_many!(emails) do
    Enum.each(emails, &mark_deleted!/1)
  end

  defp extract_headers(headers) do
    map = for h <- headers, into: %{}, do: {h.name, h.value}
    {map, parse_list_unsubscribe(map["List-Unsubscribe"])}
  end

  defp parse_list_unsubscribe(nil), do: %{}

  defp parse_list_unsubscribe(val) do
    links =
      Regex.scan(~r/<([^>]+)>|([^,\s]+)/, val)
      |> Enum.map(fn [_, a, b] -> a || b end)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    %{
      mailto: Enum.find(links, &String.starts_with?(&1, "mailto:")),
      http: Enum.find(links, &String.starts_with?(&1, "http"))
    }
  end

  defp extract_body(%{mimeType: "multipart/alternative", parts: parts}), do: extract_alt(parts)
  defp extract_body(%{mimeType: "text/plain", body: body}), do: {decode(body), nil}
  defp extract_body(%{mimeType: "text/html", body: body}), do: {nil, decode(body)}
  defp extract_body(%{parts: parts}) when is_list(parts), do: extract_alt(parts)
  defp extract_body(_), do: {nil, nil}

  defp extract_alt(parts) do
    text = parts |> Enum.find(&(&1.mimeType == "text/plain")) |> then(&(&1 && decode(&1.body)))
    html = parts |> Enum.find(&(&1.mimeType == "text/html")) |> then(&(&1 && decode(&1.body)))
    {text, html}
  end

  defp decode(%{data: data}) when is_binary(data) do
    data |> String.replace("-", "+") |> String.replace("_", "/") |> Base.decode64!()
  rescue
    _ -> nil
  end

  defp decode(_), do: nil
end
