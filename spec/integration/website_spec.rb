require 'spec_helper'

describe 'Website', :js, type: :feature do
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
