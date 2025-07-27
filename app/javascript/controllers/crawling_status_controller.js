import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    sessionId: Number
  }
  
  connect() {
    console.log("Crawling status controller connected (polling disabled)", {
      sessionId: this.sessionIdValue
    })
    
    // 폴링 제거 - Webhook과 Turbo Streams만 사용
    // 모든 상태 변경은 Node.js webhook을 통해 실시간으로 전달됨
  }
  
  disconnect() {
    console.log(`[CrawlingStatus] Disconnecting controller for session ${this.sessionIdValue}`)
    // 폴링 관련 코드 모두 제거됨
  }
}