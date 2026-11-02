import {safeVendorURL} from './tournament-vendors.js?v=20261028-tournament-planning';
export const planningStatuses={considering:'Considering',registered:'Registered',confirmed:'Confirmed',completed:'Completed',cancelled:'Cancelled'};
export function planningValues(data){
 const values={vendor_id:data.get('vendor_id')||null,end_date:data.get('end_date')||null,start_time:data.get('start_time')||null,registration_deadline:data.get('registration_deadline')||null,registration_url:safeVendorURL(data.get('registration_url')),planning_status:data.get('planning_status')||'considering'};
 if(!Object.hasOwn(planningStatuses,values.planning_status))throw Error('Choose a tournament status.');
 for(const key of ['end_date','registration_deadline']){const date=values[key];if(date&&(!/^\d{4}-\d{2}-\d{2}$/.test(date)||!Number.isFinite(Date.parse(date+'T12:00:00Z'))||new Date(date+'T12:00:00Z').toISOString().slice(0,10)!==date))throw Error('Enter a valid date.');}
 const start=data.get('event_date');if(values.end_date&&(!start||values.end_date<start||(Date.parse(values.end_date)-Date.parse(start))/86400000>6))throw Error('Choose an end date within seven days of the start date.');
 if(values.start_time&&!/^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(values.start_time))throw Error('Enter a valid start time.');return values;
}
