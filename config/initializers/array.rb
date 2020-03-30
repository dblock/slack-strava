class Array
  def and(&block)
    join_with 'and', &block
  end

  def or(&block)
    join_with 'or', &block
  end

  private

  def join_with(separator, &block)
    if count > 1
      "#{self[0..-2].map { |i| apply(i, &block) }.join(', ')} #{separator} #{apply(self[-1], &block)}"
    else
      apply(first, &block)
    end
  end

  def apply(item, &block)
    block ? block.call(item) : item
  end
end
