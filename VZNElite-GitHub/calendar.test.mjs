import test from 'node:test';import assert from 'node:assert/strict';
import {weeklyDates,monthEnd,monthCells} from './public/calendar-model.js';
test('every Thursday of a month includes the fifth Thursday',()=>assert.deepEqual(weeklyDates('2026-10-01','2026-10-31',4),['2026-10-01','2026-10-08','2026-10-15','2026-10-22','2026-10-29']));
test('weekday range starts on or after the requested date and crosses DST without time drift',()=>assert.deepEqual(weeklyDates('2026-10-30','2026-11-15',4),['2026-11-05','2026-11-12']));
test('leap year month end and calendar padding are correct',()=>{assert.equal(monthEnd('2028-02-03'),'2028-02-29');const cells=monthCells(2026,9);assert.equal(cells.length,42);assert.equal(cells[0].date,'2026-09-27');assert.equal(cells.filter(c=>c.inMonth).length,31);});
test('invalid or unbounded recurrence is rejected',()=>{assert.throws(()=>weeklyDates('2026-02-30','2026-03-10',4));assert.throws(()=>weeklyDates('2026-10-10','2026-10-01',4));assert.throws(()=>weeklyDates('2026-10-01','2028-10-01',4));});
