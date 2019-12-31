defmodule TwitterWeb.PageController do
  use TwitterWeb, :controller

  def login(conn, _params) do
    conn
    |> render("login.html")
  end

  def homepage(conn, _params) do
    render(conn, "homepage.html")
  end

  def searchquery(conn, _params) do
    render(conn, "search_query.html")
  end

  def usermessage(conn, _params) do
    render(conn, "user_message.html")
  end
end
