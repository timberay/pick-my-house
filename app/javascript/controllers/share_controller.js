import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { title: String, url: String }

  async open() {
    // urlValue (from the view) wins; fallback to current page URL.
    const url = this.hasUrlValue && this.urlValue ? this.urlValue : window.location.href
    const payload = { title: this.titleValue, url }
    try {
      if (navigator.share) {
        await navigator.share(payload)
      } else if (navigator.clipboard) {
        await navigator.clipboard.writeText(url)
        alert("링크를 복사했어요. 카카오톡이나 메시지 앱에 붙여넣기 하세요.")
      } else {
        alert(url)
      }
    } catch (e) {
      // user canceled share sheet — no-op
    }
  }
}
