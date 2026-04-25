import { Controller } from "@hotwired/stimulus"

// Toggles the `dark` class on <html> and persists the choice in localStorage.
// On connect, syncs the icons to the current state. The initial class is set
// by an inline script in <head> to avoid a flash of light content.
export default class extends Controller {
  static targets = ["sunIcon", "moonIcon"]

  connect() {
    this.sync()
  }

  toggle() {
    const root = document.documentElement
    const next = !root.classList.contains("dark")
    root.classList.toggle("dark", next)
    localStorage.setItem("dark-mode", next ? "true" : "false")
    this.sync()
  }

  sync() {
    const isDark = document.documentElement.classList.contains("dark")
    if (this.hasSunIconTarget) this.sunIconTarget.classList.toggle("hidden", isDark)
    if (this.hasMoonIconTarget) this.moonIconTarget.classList.toggle("hidden", !isDark)
  }
}
