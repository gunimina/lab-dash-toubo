import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { autoDismiss: Number }
  
  connect() {
    if (this.autoDismissValue && this.autoDismissValue > 0) {
      this.timeout = setTimeout(() => {
        this.dismiss()
      }, this.autoDismissValue)
    }
  }
  
  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
  
  dismiss() {
    this.element.style.transition = "opacity 300ms, transform 300ms"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateX(100%)"
    
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}