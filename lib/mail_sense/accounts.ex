defmodule MailSense.Accounts do
  import Ecto.Query

  alias MailSense.Repo
  alias MailSense.Accounts.GmailAccount
  alias MailSense.Accounts.User
  alias MailSense.Mail.Category
  alias MailSense.Mail.GmailClient
  alias OAuth2.Client

  def get_user(id), do: Repo.get(User, id)

  def get_or_create_user!(email, name) do
    case Repo.get_by(User, email: email) do
      nil ->
        %User{}
        |> User.changeset(%{email: email, name: name})
        |> Repo.insert!()

      user ->
        user
    end
  end

  def upsert_gmail_account!(%User{id: uid}, attrs) do
    Repo.insert!(
      %GmailAccount{}
      |> GmailAccount.changeset(Map.put(attrs, :user_id, uid)),
      on_conflict: [set: Map.to_list(Map.drop(attrs, [:user_id]))],
      conflict_target: [:user_id, :email]
    )
  end

  def list_gmail_accounts_for_user(uid),
    do: Repo.all(from g in GmailAccount, where: g.user_id == ^uid)

  def list_gmail_accounts(), do: Repo.all(GmailAccount)

  def google_connection(%GmailAccount{} = acct) do
    if acct.expires_at && DateTime.compare(acct.expires_at, DateTime.utc_now()) == :lt do
      with {:ok, %Client{token: %{access_token: access, expires_at: _exp}}} <- refresh_token(acct) do
        {:ok, GmailClient.connection(access), access}
      end
    else
      {:ok, GmailClient.connection(acct.access_token), acct.access_token}
    end
  end

  defp refresh_token(acct) do
    client =
      OAuth2.Client.new(
        strategy: OAuth2.Strategy.Refresh,
        client_id: System.fetch_env!("GOOGLE_CLIENT_ID"),
        client_secret: System.fetch_env!("GOOGLE_CLIENT_SECRET"),
        site: "https://oauth2.googleapis.com"
      )

    OAuth2.Client.refresh_token(client, acct.refresh_token)
  end

  # Categories
  def list_categories_for_user(uid),
    do: Repo.all(from c in Category, where: c.user_id == ^uid)

  def get_or_create_category_by_name!(uid, name) do
    Repo.get_by(Category, user_id: uid, name: name) ||
      Repo.insert!(%Category{user_id: uid, name: name})
  end
end
