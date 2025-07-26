namespace :tailwind do
  desc "하드코딩된 색상 및 스타일 찾기"
  task :audit do
    puts "\n🔍 Tailwind 감사 시작...\n"
    
    issues_found = false
    
    # 검사할 파일 패턴
    file_patterns = [
      "app/views/**/*.erb",
      "app/javascript/**/*.js",
      "app/helpers/**/*.rb"
    ]
    
    # 하드코딩된 패턴 정의
    hardcoded_patterns = {
      hex_colors: /(?:class|className)=["'][^"']*#[0-9a-fA-F]{3,6}[^"']*["']/,
      rgb_colors: /(?:class|className)=["'][^"']*rgb[a]?\([^)]+\)[^"']*["']/,
      bracket_colors: /(?:class|className)=["'][^"']*\[[#]?[0-9a-fA-F]{3,6}\][^"']*["']/,
      custom_spacing: /(?:class|className)=["'][^"']*\[([\d.]+(?:px|rem|em|%))\][^"']*["']/,
      inline_styles: /style=["'][^"']+["']/
    }
    
    file_patterns.each do |pattern|
      Dir.glob(pattern).each do |file|
        content = File.read(file)
        line_number = 0
        
        content.each_line do |line|
          line_number += 1
          
          hardcoded_patterns.each do |pattern_name, regex|
            if line.match?(regex)
              issues_found = true
              puts "⚠️  #{file}:#{line_number}"
              puts "   Pattern: #{pattern_name}"
              puts "   Line: #{line.strip}"
              puts ""
            end
          end
        end
      end
    end
    
    if issues_found
      puts "❌ 하드코딩된 스타일이 발견되었습니다!"
      puts "\n권장사항:"
      puts "1. 하드코딩된 색상은 Tailwind 유틸리티 클래스로 변경하세요"
      puts "2. 커스텀 값이 필요한 경우 tailwind.config.js에 정의하세요"
      puts "3. 인라인 스타일 대신 Tailwind 클래스를 사용하세요"
    else
      puts "✅ 하드코딩된 스타일이 발견되지 않았습니다!"
    end
  end
  
  desc "Tailwind 클래스 사용 통계"
  task :stats do
    puts "\n📊 Tailwind 사용 통계\n"
    
    class_usage = Hash.new(0)
    
    Dir.glob("app/views/**/*.erb").each do |file|
      content = File.read(file)
      
      # class 속성에서 클래스 추출
      content.scan(/class=["']([^"']+)["']/).each do |match|
        classes = match[0].split(/\s+/)
        classes.each { |cls| class_usage[cls] += 1 }
      end
    end
    
    # 카테고리별로 분류
    categories = {
      colors: /^(bg|text|border|ring)-/,
      spacing: /^(p|m|px|py|pt|pb|pl|pr|mx|my|mt|mb|ml|mr)-/,
      layout: /^(flex|grid|block|inline|hidden|container)/,
      typography: /^(text|font|leading|tracking)/,
      effects: /^(shadow|opacity|transition|transform|animate)/
    }
    
    categorized = Hash.new { |h, k| h[k] = [] }
    
    class_usage.each do |cls, count|
      matched = false
      categories.each do |category, pattern|
        if cls.match?(pattern)
          categorized[category] << [cls, count]
          matched = true
          break
        end
      end
      categorized[:other] << [cls, count] unless matched
    end
    
    # 결과 출력
    categorized.each do |category, classes|
      next if classes.empty?
      
      puts "\n#{category.to_s.capitalize}:"
      classes.sort_by { |_, count| -count }.first(10).each do |cls, count|
        puts "  #{cls}: #{count}회"
      end
    end
    
    puts "\n총 고유 클래스 수: #{class_usage.size}"
    puts "총 클래스 사용 횟수: #{class_usage.values.sum}"
  end
end