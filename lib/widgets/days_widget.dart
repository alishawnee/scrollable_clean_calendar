import 'package:flutter/material.dart';
import 'package:scrollable_clean_calendar/controllers/clean_calendar_controller.dart';
import 'package:scrollable_clean_calendar/models/day_values_model.dart';
import 'package:scrollable_clean_calendar/utils/enums.dart';
import 'package:scrollable_clean_calendar/utils/extensions.dart';

// import ReservatedDay and ShiftType from the model above
// (put model in a file like models/day_reservation.dart and import here)

class DaysWidget extends StatelessWidget {
  final CleanCalendarController cleanCalendarController;
  final DateTime month;
  final double calendarCrossAxisSpacing;
  final double calendarMainAxisSpacing;
  final Layout? layout;
  final Widget Function(BuildContext context, DayValues values)? dayBuilder;
  final Color? selectedBackgroundColor;
  final Color? backgroundColor;
  final Color? selectedBackgroundColorBetween;
  final Color? disableBackgroundColor;
  final Color? dayDisableColor;
  final double radius;
  final TextStyle? textStyle;
  final double? aspectRatio;

  // --- NEW: reservations and shift colors / builder
  final List<ReservatedDay>? reservations;
  final Color? shiftFullColor;
  final Color? shiftDayColor; // color for top-half
  final Color? shiftNightColor; // color for bottom-half
  final Widget Function(
    BuildContext context,
    DayValues values,
    ReservatedDay reservation,
  )?
  shiftWidgetBuilder;
  // --- end new

  const DaysWidget({
    super.key,
    required this.month,
    required this.cleanCalendarController,
    required this.calendarCrossAxisSpacing,
    required this.calendarMainAxisSpacing,
    required this.layout,
    required this.dayBuilder,
    required this.selectedBackgroundColor,
    required this.backgroundColor,
    required this.selectedBackgroundColorBetween,
    required this.disableBackgroundColor,
    required this.dayDisableColor,
    required this.radius,
    required this.textStyle,
    required this.aspectRatio,
    this.reservations,
    this.shiftFullColor,
    this.shiftDayColor,
    this.shiftNightColor,
    this.shiftWidgetBuilder,
  });

  // helper: find reservation covering this day (returns first match)
  ReservatedDay? _findReservationForDay(DateTime day) {
    if (reservations == null) return null;
    for (final r in reservations!) {
      if (r.contains(day)) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    int monthPositionStartDay =
        (cleanCalendarController.weekdayStart -
                DateTime.daysPerWeek -
                DateTime(month.year, month.month).weekday)
            .abs();
    monthPositionStartDay =
        monthPositionStartDay > DateTime.daysPerWeek
            ? monthPositionStartDay - DateTime.daysPerWeek
            : monthPositionStartDay;

    final start = monthPositionStartDay == 7 ? 0 : monthPositionStartDay;

    return GridView.count(
      crossAxisCount: DateTime.daysPerWeek,
      physics: const NeverScrollableScrollPhysics(),
      addRepaintBoundaries: false,
      padding: EdgeInsets.zero,
      crossAxisSpacing: calendarCrossAxisSpacing,
      mainAxisSpacing: calendarMainAxisSpacing,
      shrinkWrap: true,
      childAspectRatio: aspectRatio ?? 1.0,
      children: List.generate(
        DateTime(month.year, month.month + 1, 0).day + start,
        (index) {
          if (index < start) return const SizedBox.shrink();
          final day = DateTime(month.year, month.month, (index + 1 - start));
          final text = (index + 1 - start).toString();

          bool isSelected = false;

          if (cleanCalendarController.rangeMinDate != null) {
            if (cleanCalendarController.rangeMinDate != null &&
                cleanCalendarController.rangeMaxDate != null) {
              isSelected =
                  day.isSameDayOrAfter(cleanCalendarController.rangeMinDate!) &&
                  day.isSameDayOrBefore(cleanCalendarController.rangeMaxDate!);
            } else {
              isSelected = day.isAtSameMomentAs(
                cleanCalendarController.rangeMinDate!,
              );
            }
          }

          final dayValues = DayValues(
            day: day,
            isFirstDayOfWeek:
                day.weekday == cleanCalendarController.weekdayStart,
            isLastDayOfWeek: day.weekday == cleanCalendarController.weekdayEnd,
            isSelected: isSelected,
            maxDate: cleanCalendarController.maxDate,
            minDate: cleanCalendarController.minDate,
            text: text,
            selectedMaxDate: cleanCalendarController.rangeMaxDate,
            selectedMinDate: cleanCalendarController.rangeMinDate,
          );

          Widget widgetForDay;
          final reservation = _findReservationForDay(day);

          if (dayBuilder != null) {
            // If user provided full custom dayBuilder, call it.
            widgetForDay = dayBuilder!(context, dayValues);
          } else {
            // If user provided a shiftWidgetBuilder and reservation exists, use it
            if (reservation != null && shiftWidgetBuilder != null) {
              widgetForDay = shiftWidgetBuilder!(
                context,
                dayValues,
                reservation,
              );
            } else {
              // default rendering (pattern/beauty) but wrapped to support shifts
              widgetForDay =
                  <Layout, Widget Function()>{
                    Layout.DEFAULT:
                        () => _pattern(context, dayValues, reservation),
                    Layout.BEAUTY:
                        () => _beauty(context, dayValues, reservation),
                  }[layout]!();
            }
          }

          return GestureDetector(
            onTap: () {
              if (day.isBefore(cleanCalendarController.minDate) &&
                  !day.isSameDay(cleanCalendarController.minDate)) {
                if (cleanCalendarController.onPreviousMinDateTapped != null) {
                  cleanCalendarController.onPreviousMinDateTapped!(day);
                }
              } else if (day.isAfter(cleanCalendarController.maxDate)) {
                if (cleanCalendarController.onAfterMaxDateTapped != null) {
                  cleanCalendarController.onAfterMaxDateTapped!(day);
                }
              } else {
                if (!cleanCalendarController.readOnly) {
                  cleanCalendarController.onDayClick(day);
                }
              }
            },
            child: widgetForDay,
          );
        },
      ),
    );
  }

  // Builds background taking into account reservation (shift) — used by both patterns
  Widget _buildShiftAwareContainer({
    required BuildContext context,
    required DayValues values,
    required Widget child,
    ReservatedDay? reservation,
    BorderRadius? borderRadius,
    Color? defaultBg,
    Color? textColorFallback,
  }) {
    final bg = defaultBg ?? Theme.of(context).colorScheme.surface;
    final selectedBgColor =
        selectedBackgroundColor ?? Theme.of(context).colorScheme.primary;
    final shiftFull = shiftFullColor ?? Theme.of(context).colorScheme.secondary;
    final shiftDay = shiftDayColor ?? (shiftFull.withOpacity(.9));
    final shiftNight = shiftNightColor ?? (shiftFull.withOpacity(.7));

    // If there's a reservation, render stacking: shift band + child content
    if (reservation != null) {
      // for full shift
      if (reservation.shiftType == ShiftType.FULL) {
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: shiftFull,
            borderRadius: borderRadius ?? BorderRadius.circular(radius),
            border:
                values.day.isSameDay(values.minDate)
                    ? Border.all(
                      color:
                          selectedBackgroundColor ??
                          Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                    : null,
          ),
          child: child,
        );
      }

      // for half (DAY -> top, NIGHT -> bottom)
      final isTop = reservation.shiftType == ShiftType.DAY;

      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: borderRadius ?? BorderRadius.circular(radius),
          // we don't set border here for halves; child can show selection border
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // colored half
            Align(
              alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: isTop ? shiftDay : shiftNight,
                    borderRadius:
                        isTop
                            ? BorderRadius.only(
                              topLeft: Radius.circular(radius),
                              topRight: Radius.circular(radius),
                            )
                            : BorderRadius.only(
                              bottomLeft: Radius.circular(radius),
                              bottomRight: Radius.circular(radius),
                            ),
                  ),
                ),
              ),
            ),
            // content on top (day number)
            Center(child: child),
          ],
        ),
      );
    }

    // no reservation -> fallback to normal logic (selected/disabled/etc)
    Color renderBg = bg;
    TextStyle txtStyle = (textStyle ?? Theme.of(context).textTheme.bodyLarge)!
        .copyWith(
          color:
              backgroundColor != null
                  ? backgroundColor!.computeLuminance() > .5
                      ? Colors.black
                      : Colors.white
                  : Theme.of(context).colorScheme.onSurface,
        );

    if (values.isSelected) {
      if ((values.selectedMinDate != null &&
              values.day.isSameDay(values.selectedMinDate!)) ||
          (values.selectedMaxDate != null &&
              values.day.isSameDay(values.selectedMaxDate!))) {
        renderBg =
            selectedBackgroundColor ?? Theme.of(context).colorScheme.primary;
        txtStyle = (textStyle ?? Theme.of(context).textTheme.bodyLarge)!
            .copyWith(
              color:
                  selectedBackgroundColor != null
                      ? selectedBackgroundColor!.computeLuminance() > .5
                          ? Colors.black
                          : Colors.white
                      : Theme.of(context).colorScheme.onPrimary,
            );
      } else {
        renderBg =
            selectedBackgroundColorBetween ??
            Theme.of(context).colorScheme.primary.withOpacity(.3);
        txtStyle = (textStyle ?? Theme.of(context).textTheme.bodyLarge)!
            .copyWith(
              color:
                  selectedBackgroundColor ??
                  Theme.of(context).colorScheme.primary,
            );
      }
    } else if (values.day.isSameDay(values.minDate)) {
      renderBg = Colors.transparent;
      txtStyle = (textStyle ?? Theme.of(context).textTheme.bodyLarge)!.copyWith(
        color: selectedBackgroundColor ?? Theme.of(context).colorScheme.primary,
      );
    } else if (values.day.isBefore(values.minDate) ||
        values.day.isAfter(values.maxDate)) {
      renderBg =
          disableBackgroundColor ??
          Theme.of(context).colorScheme.surface.withOpacity(.4);
      txtStyle = (textStyle ?? Theme.of(context).textTheme.bodyLarge)!.copyWith(
        color:
            dayDisableColor ??
            Theme.of(context).colorScheme.onSurface.withOpacity(.5),
        decoration: TextDecoration.lineThrough,
      );
    }

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: renderBg,
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
        border:
            values.day.isSameDay(values.minDate)
                ? Border.all(
                  color:
                      selectedBackgroundColor ??
                      Theme.of(context).colorScheme.primary,
                  width: 2,
                )
                : null,
      ),
      child: DefaultTextStyle(style: txtStyle, child: child),
    );
  }

  Widget _pattern(
    BuildContext context,
    DayValues values,
    ReservatedDay? reservation,
  ) {
    final textStyleLocal = (textStyle ?? Theme.of(context).textTheme.bodyLarge)!
        .copyWith(
          color:
              backgroundColor != null
                  ? backgroundColor!.computeLuminance() > .5
                      ? Colors.black
                      : Colors.white
                  : Theme.of(context).colorScheme.onSurface,
        );

    final child = Text(
      values.text,
      textAlign: TextAlign.center,
      style: textStyleLocal,
    );

    return _buildShiftAwareContainer(
      context: context,
      values: values,
      reservation: reservation,
      defaultBg: backgroundColor,
      child: child,
    );
  }

  Widget _beauty(
    BuildContext context,
    DayValues values,
    ReservatedDay? reservation,
  ) {
    BorderRadiusGeometry? borderRadius;
    Color bgColor = Colors.transparent;
    TextStyle txtStyle = (textStyle ?? Theme.of(context).textTheme.bodyLarge)!
        .copyWith(
          color:
              backgroundColor != null
                  ? backgroundColor!.computeLuminance() > .5
                      ? Colors.black
                      : Colors.white
                  : Theme.of(context).colorScheme.onSurface,
          fontWeight:
              values.isFirstDayOfWeek || values.isLastDayOfWeek
                  ? FontWeight.bold
                  : null,
        );

    // NOTE: we will forward the decision to _buildShiftAwareContainer for reservation cases
    final child = Text(
      values.text,
      textAlign: TextAlign.center,
      style: txtStyle,
    );

    return _buildShiftAwareContainer(
      context: context,
      values: values,
      reservation: reservation,
      borderRadius: BorderRadius.circular(radius),
      defaultBg: bgColor,
      child: child,
    );
  }
}
