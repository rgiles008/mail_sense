defmodule MailSense.Mail.MailContext do
  import Ecto.Query

  alias MailSense.Repo
  alias MailSense.Mail.Category
  alias MailSense.Mail.Email
  alias MailSense.Mail.GmailClient
  alias MailSense.Accounts.GmailAccount

  def upsert_email!(acct_id, parsed, category, summary, reason) do
    attrs =
      Map.merge(parsed, %{
        gmail_account_id: acct_id,
        category_id: category.id,
        ai_summary: summary,
        ai_category_reason: reason,
        archived_at: DateTime.utc_now()
      })

    %Email{}
    |> Email.changeset(attrs)
    |> Repo.insert!(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :gmail_message_id
    )
  end

  def list_emails_by_category(cat_id) do
    Repo.all(from e in Email, where: e.category_id == ^cat_id, order_by: [desc: e.inserted_at])
  end

  def list_emails_by_ids(user_id, email_ids) do
    Repo.all(
      from e in Email,
        join: g in GmailAccount,
        on: g.id == e.gmail_account_id,
        where: g.user_id == ^user_id and e.id in ^email_ids,
        preload: [gmail_account: g]
    )
  end

  def persist_categorized!(acct, parsed, %Category{} = category, summary) do
    attrs =
      parsed
      |> Map.merge(%{
        gmail_account_id: acct.id,
        category_id: category.id,
        ai_summary: summary,
        archived_at: DateTime.utc_now()
      })

    %Email{}
    |> Email.changeset(attrs)
    |> Repo.insert!(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :gmail_message_id
    )
  end

  def archive_and_label(conn, user_email, mid, %Category{} = category) do
    label_id = ensure_gmail_label!(conn, user_email, category)

    GmailClient.modify_labels(
      conn,
      user_email,
      mid,
      Enum.reject([label_id], &(&1 in [nil, ""])),
      ["INBOX"]
    )
  end

  defp ensure_gmail_label!(_conn, _user_email, %Category{gmail_label_id: id})
       when is_binary(id) and id != "" do
    id
  end

  defp ensure_gmail_label!(conn, user_email, %Category{} = category) do
    case GmailClient.create_label(conn, user_email, category.name) do
      {:ok, %GoogleApi.Gmail.V1.Model.Label{id: id}} ->
        category |> Ecto.Changeset.change(gmail_label_id: id) |> Repo.update!()
        id

      _ ->
        ""
    end
  end
end
