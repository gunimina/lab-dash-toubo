// Progress bar 업데이트 헬퍼
export function updateProgressBar(elementId, progress) {
  const element = document.getElementById(elementId);
  if (element) {
    element.style.width = `${progress}%`;
    element.setAttribute('data-progress', progress);
  }
}

// 페이지 로드 시 data-progress 속성을 읽어서 초기화
export function initializeProgressBars() {
  document.querySelectorAll('[data-progress]').forEach(element => {
    const progress = element.getAttribute('data-progress');
    if (progress) {
      element.style.width = `${progress}%`;
    }
  });
}

// DOM이 로드되면 자동으로 초기화
document.addEventListener('DOMContentLoaded', initializeProgressBars);