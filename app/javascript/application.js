// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// 전역 유틸리티 함수들
window.utils = {
  // CSRF 토큰 가져오기
  getCSRFToken() {
    return document.querySelector('[name="csrf-token"]')?.content;
  },
  
  // Fetch API 래퍼
  async fetchJSON(url, options = {}) {
    const defaultOptions = {
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      }
    };
    
    const response = await fetch(url, { ...defaultOptions, ...options });
    if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
    return response.json();
  }
};

console.log('Lab Shop Dashboard with Turbo & Stimulus loaded');

// Turbo Stream 이벤트 디버깅
document.addEventListener('turbo:before-stream-render', (event) => {
  console.log('Turbo Stream rendering:', event.detail.newStream);
});

document.addEventListener('turbo:render', (event) => {
  console.log('Turbo rendered:', event.detail);
});

document.addEventListener('turbo:frame-missing', (event) => {
  console.error('Turbo frame missing:', event.detail);
  event.preventDefault(); // 기본 에러 처리 방지
});
