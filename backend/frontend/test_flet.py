import flet as ft
def main(page: ft.Page):
    page.add(ft.Text("Testing Flet!"))
    page.update()
ft.app(target=main)
