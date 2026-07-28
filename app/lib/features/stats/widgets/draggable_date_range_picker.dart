import 'package:flutter/material.dart';

/// Takvimdeki iki uç noktayı sürükleyerek düzenleten özel tarih aralığı seçici.
///
/// Yerleşik tarih aralığı seçicinin görünümünü koruyan bu küçük diyalog, uçları
/// en az 44px dokunma alanıyla sunar. Bir uç diğerinin ötesine bırakılırsa
/// hata vermek yerine uçlar yer değiştirir.
class DraggableDateRangePickerDialog extends StatefulWidget {
  const DraggableDateRangePickerDialog({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.initialRange,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange initialRange;

  @override
  State<DraggableDateRangePickerDialog> createState() =>
      _DraggableDateRangePickerDialogState();
}

enum _RangeEndpoint { start, end }

class _DraggableDateRangePickerDialogState
    extends State<DraggableDateRangePickerDialog> {
  late DateTime _start;
  late DateTime _end;
  late DateTime _displayedMonth;
  _RangeEndpoint _activeEndpoint = _RangeEndpoint.start;
  DateTime? _previewStart;
  DateTime? _previewEnd;

  @override
  void initState() {
    super.initState();
    _start = _day(widget.initialRange.start);
    _end = _day(widget.initialRange.end);
    _displayedMonth = DateTime(_start.year, _start.month);
  }

  DateTime get _visibleStart => _previewStart ?? _start;
  DateTime get _visibleEnd => _previewEnd ?? _end;

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  bool _isSelectable(DateTime day) =>
      !day.isBefore(_day(widget.firstDate)) &&
      !day.isAfter(_day(widget.lastDate));

  (DateTime, DateTime) _withEndpoint(_RangeEndpoint endpoint, DateTime day) {
    final normalized = _day(day);
    // Önizleme birden fazla hedefe girip çıkarken yeni bir kaynak aralık gibi
    // kullanılmamalı. Bırakma, her zaman son onaylanan aralığa göre hesaplanır.
    final start = _start;
    final end = _end;
    if (endpoint == _RangeEndpoint.start) {
      return normalized.isAfter(end) ? (end, normalized) : (normalized, end);
    }
    return normalized.isBefore(start)
        ? (normalized, start)
        : (start, normalized);
  }

  void _previewEndpoint(_RangeEndpoint endpoint, DateTime day) {
    final (start, end) = _withEndpoint(endpoint, day);
    setState(() {
      _previewStart = start;
      _previewEnd = end;
    });
  }

  void _applyEndpoint(_RangeEndpoint endpoint, DateTime day) {
    final (start, end) = _withEndpoint(endpoint, day);
    setState(() {
      _start = start;
      _end = end;
      _previewStart = null;
      _previewEnd = null;
      _activeEndpoint = endpoint;
    });
  }

  void _clearPreview() {
    if (_previewStart == null && _previewEnd == null) return;
    setState(() {
      _previewStart = null;
      _previewEnd = null;
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inVisibleRange(DateTime day) =>
      !day.isBefore(_visibleStart) && !day.isAfter(_visibleEnd);

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localizations.dateRangePickerHelpText,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _EndpointHandle(
                      key: const ValueKey('range-handle-start'),
                      endpoint: _RangeEndpoint.start,
                      date: _visibleStart,
                      selected: _activeEndpoint == _RangeEndpoint.start,
                      semanticLabel: localizations
                          .dateRangeStartDateSemanticLabel(
                            localizations.formatMediumDate(_visibleStart),
                          ),
                      onTap: () => setState(
                        () => _activeEndpoint = _RangeEndpoint.start,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _EndpointHandle(
                      key: const ValueKey('range-handle-end'),
                      endpoint: _RangeEndpoint.end,
                      date: _visibleEnd,
                      selected: _activeEndpoint == _RangeEndpoint.end,
                      semanticLabel: localizations
                          .dateRangeEndDateSemanticLabel(
                            localizations.formatMediumDate(_visibleEnd),
                          ),
                      onTap: () =>
                          setState(() => _activeEndpoint = _RangeEndpoint.end),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    tooltip: localizations.previousMonthTooltip,
                    onPressed: _displayedMonth.isAfter(firstMonth)
                        ? () => setState(() {
                            _displayedMonth = DateTime(
                              _displayedMonth.year,
                              _displayedMonth.month - 1,
                            );
                          })
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      localizations.formatMonthYear(_displayedMonth),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: localizations.nextMonthTooltip,
                    onPressed: _displayedMonth.isBefore(lastMonth)
                        ? () => setState(() {
                            _displayedMonth = DateTime(
                              _displayedMonth.year,
                              _displayedMonth.month + 1,
                            );
                          })
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              _CalendarGrid(
                displayedMonth: _displayedMonth,
                selectable: _isSelectable,
                inRange: _inVisibleRange,
                isStart: (day) => _sameDay(day, _visibleStart),
                isEnd: (day) => _sameDay(day, _visibleEnd),
                activeEndpoint: _activeEndpoint,
                onPreview: _previewEndpoint,
                onLeave: _clearPreview,
                onAccept: _applyEndpoint,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(localizations.cancelButtonLabel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(DateTimeRange(start: _start, end: _end)),
                    child: Text(localizations.saveButtonLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndpointHandle extends StatelessWidget {
  const _EndpointHandle({
    super.key,
    required this.endpoint,
    required this.date,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  final _RangeEndpoint endpoint;
  final DateTime date;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Draggable<_RangeEndpoint>(
        data: endpoint,
        maxSimultaneousDrags: 1,
        feedback: Material(
          color: Colors.transparent,
          child: _HandleBody(
            date: date,
            color: theme.colorScheme.primaryContainer,
            textColor: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.45,
          child: _HandleBody(
            date: date,
            color: color,
            textColor: theme.colorScheme.onSurface,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: _HandleBody(
            date: date,
            color: color,
            textColor: selected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _HandleBody extends StatelessWidget {
  const _HandleBody({
    required this.date,
    required this.color,
    required this.textColor,
  });

  final DateTime date;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      MaterialLocalizations.of(context).formatMediumDate(date),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: textColor),
    ),
  );
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.displayedMonth,
    required this.selectable,
    required this.inRange,
    required this.isStart,
    required this.isEnd,
    required this.activeEndpoint,
    required this.onPreview,
    required this.onLeave,
    required this.onAccept,
  });

  final DateTime displayedMonth;
  final bool Function(DateTime) selectable;
  final bool Function(DateTime) inRange;
  final bool Function(DateTime) isStart;
  final bool Function(DateTime) isEnd;
  final _RangeEndpoint activeEndpoint;
  final void Function(_RangeEndpoint, DateTime) onPreview;
  final VoidCallback onLeave;
  final void Function(_RangeEndpoint, DateTime) onAccept;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final first = DateTime(displayedMonth.year, displayedMonth.month);
    final offset = first.weekday % DateTime.daysPerWeek;
    final days = DateUtils.getDaysInMonth(first.year, first.month);
    final totalCells = ((offset + days + 6) ~/ 7) * 7;

    return Column(
      children: [
        Row(
          children: [
            for (final label in localizations.narrowWeekdays)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: DateTime.daysPerWeek,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - offset + 1;
            if (dayNumber < 1 || dayNumber > days) return const SizedBox();
            final day = DateTime(first.year, first.month, dayNumber);
            return _DayTarget(
              key: ValueKey('date-${day.toIso8601String().substring(0, 10)}'),
              day: day,
              selectable: selectable(day),
              selected: isStart(day) || isEnd(day),
              inRange: inRange(day),
              activeEndpoint: activeEndpoint,
              onPreview: onPreview,
              onLeave: onLeave,
              onAccept: onAccept,
            );
          },
        ),
      ],
    );
  }
}

class _DayTarget extends StatelessWidget {
  const _DayTarget({
    super.key,
    required this.day,
    required this.selectable,
    required this.selected,
    required this.inRange,
    required this.activeEndpoint,
    required this.onPreview,
    required this.onLeave,
    required this.onAccept,
  });

  final DateTime day;
  final bool selectable;
  final bool selected;
  final bool inRange;
  final _RangeEndpoint activeEndpoint;
  final void Function(_RangeEndpoint, DateTime) onPreview;
  final VoidCallback onLeave;
  final void Function(_RangeEndpoint, DateTime) onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = selected
        ? theme.colorScheme.primary
        : inRange
        ? theme.colorScheme.primaryContainer
        : Colors.transparent;
    final textColor = !selectable
        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
        : selected
        ? theme.colorScheme.onPrimary
        : inRange
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return DragTarget<_RangeEndpoint>(
      onWillAcceptWithDetails: (details) {
        if (!selectable) return false;
        onPreview(details.data, day);
        return true;
      },
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (details) => onAccept(details.data, day),
      builder: (context, _, _) => InkWell(
        onTap: selectable ? () => onAccept(activeEndpoint, day) : null,
        customBorder: const CircleBorder(),
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: Text(
              '$day',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}
