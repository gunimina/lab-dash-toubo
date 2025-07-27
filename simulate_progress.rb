# 진행률 업데이트 시뮬레이션 스크립트

# 새 세션 생성
session = CrawlingSession.create!(
  crawling_type: 'initial',
  status: 'running',
  started_at: Time.current
)
puts "Created session: #{session.id}"

# Step 1 진행상황 생성
progress1 = CrawlingProgress.create!(
  crawling_session: session,
  step_number: 1,
  status: 'running',
  current_progress: 0,
  message: '카테고리 수집 시작'
)

# 5초마다 진행률 업데이트
puts "\nSimulating Step 1 progress updates..."

# 카테고리 단계 (0-25%)
sleep 2
progress1.update!(current_progress: 10, message: "카테고리 수집중 (50개)")
puts "Progress: 10% - 카테고리 수집중"

sleep 2
progress1.update!(current_progress: 25, message: "카테고리 수집 완료 (100개)")
puts "Progress: 25% - 카테고리 완료"

# 부모상품 단계 (25-50%)
sleep 2
progress1.update!(current_progress: 35, message: "부모상품 수집중 (500개)")
puts "Progress: 35% - 부모상품 수집중"

sleep 2
progress1.update!(current_progress: 50, message: "부모상품 수집 완료 (2000개)")
puts "Progress: 50% - 부모상품 완료"

# 자식상품 단계 (50-75%)
sleep 2
progress1.update!(current_progress: 60, message: "자식상품 수집중 (5000개)")
puts "Progress: 60% - 자식상품 수집중"

sleep 2
progress1.update!(current_progress: 75, message: "자식상품 수집 완료 (18000개)")
puts "Progress: 75% - 자식상품 완료"

# 상세정보 단계 (75-100%)
sleep 2
progress1.update!(current_progress: 85, message: "iframe 스펙 크롤링중")
puts "Progress: 85% - 상세정보 크롤링중"

sleep 2
progress1.update!(current_progress: 100, message: "Step 1 완료!")
progress1.update!(status: 'completed')
puts "Progress: 100% - Step 1 완료!"

puts "\nStep 1 simulation completed!"
puts "Check the UI to see if progress updates are reflected in real-time."