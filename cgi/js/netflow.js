$(document).ready(function() {

	$('li.device a').click(function() {

		item = $(this);
		$('li.device').removeClass('selected');
		$('body').css({ cursor: 'wait' }).find('a').css({ cursor: 'wait' });
		$('.wrapmain').css({ cursor: 'wait' });

		$('#main').load(item.attr('href'), function() {
			$('body').css({ cursor: 'default' }).find('a').css({ cursor: 'pointer' });
			$('.wrapmain').css({ cursor: 'pointer' });

			item.parent().addClass('selected');
			bindDynamic();
		});
		return false;
	});

	$('li.device:first').addClass('selected');
	bindDynamic();
});

function bindDynamic() {
	$('body').css({ cursor: 'default' }).find('a').css({ cursor: 'pointer' });
	$('.wrapmain').css({ cursor: 'pointer' });

	$('#main a').click(function() {
		$('body').css({ cursor: 'wait' }).find('a').css({ cursor: 'wait' });
		$('.wrapmain').css({ cursor: 'wait' });

		$('#main').load($(this).attr('href'), function() { bindDynamic(); });
		return false;
	});

	/**
	 * Device detail sliders
	 */
	$('#Table.summary div.wrapmain').click(function() {
		$('#Table.summary div.wrapmain').removeClass('selected');
		$(this).addClass('selected');

		slider = '<div class="device-detail"></div>';
		sliderCreated = $(this).next().hasClass('device-detail');
		$slider = sliderCreated ? $(this).next() : $(this).after(slider).next();

		if ($slider.text().replace(/\s+/g, '') != '') {
			return $slider.slideUp(function() {
				$(this).html('').prev().removeClass('selected');
			});
		}

		$slider.load($(this).find('a:first').attr('href'), function() {
			$(this).slideDown();
		});
	});

	/**
	 * Hide the graphs if all there is is "other"
	 */
	if ($('.graphs').length) {
		$.each($('.graphs li.graph-wrap:even'), function() {
			$label = $(this).find('.legend_label');
			if ($label.length == 1 && $label.text() == 'other') {
				$(this).hide().next().hide();
			}
		});
	}
}
