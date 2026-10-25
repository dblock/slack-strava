require 'spec_helper'

describe 'Website', :js, type: :feature do
  it 'reloads generated CSS and loads its versioned artwork' do
    visit '/'
    page.refresh
    image_path = "/img/screenshot-background.svg?v=#{Digest::SHA256.file('public/img/screenshot-background.svg').hexdigest}"
    expect(page.evaluate_script("getComputedStyle(document.body, '::before').backgroundImage")).to include(image_path)
    expect(page.evaluate_async_script(<<~JS, image_path)).to be true
      const done = arguments[arguments.length - 1];
      const image = new Image();
      image.onload = () => done(image.naturalWidth > 0);
      image.onerror = () => done(false);
      image.src = arguments[0];
    JS
    expect(page).to have_css('.hero-preview img[src^="/img/notify.png?v="]') do |image|
      image.evaluate_script('this.complete && this.naturalWidth === 1236 && this.naturalHeight === 919')
    end
  end

  it 'renders native install controls and transparent artwork' do
    visit '/'

    expect(all('a.install-button.register').map(&:text)).to eq(['Add to Slack', 'Add to Slack'])
    alphas = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".hero-logo, .hero-preview img")).map(image => {
        const canvas = document.createElement("canvas");
        canvas.width = image.naturalWidth;
        canvas.height = image.naturalHeight;
        const context = canvas.getContext("2d");
        context.drawImage(image, 0, 0);
        return context.getImageData(0, 0, 1, 1).data[3];
      })
    JS
    expect(alphas).to eq([0, 0])
  end

  it 'keeps the background stable when help expands' do
    visit '/help.html'
    background = '(() => { const style = getComputedStyle(document.body, "::before"); return [style.position, style.width, style.height]; })()'
    original_background = page.evaluate_script(background)
    original_height = page.evaluate_script('document.documentElement.scrollHeight')

    find('summary', text: 'Sharing and privacy').click

    expect(page).to have_css('details[open]', text: 'set private true')
    expect(page.evaluate_script('document.documentElement.scrollHeight')).to be > original_height
    expect(original_background.first).to eq 'fixed'
    expect(page.evaluate_script(background)).to eq original_background
  end
end
