defmodule MailSenseWeb.PageController do
  use MailSenseWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
