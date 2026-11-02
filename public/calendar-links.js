export function googleCalendarURL(event){
 const stamp=event.date.replaceAll('-','')+'T'+event.time.replace(':','')+'00';
 const params=new URLSearchParams({action:'TEMPLATE',text:event.title,dates:stamp+'/'+stamp,ctz:'America/Chicago',location:event.location,details:'Sample VZN Elite event. Confirm actual arrangements with the coach. Duration has not been set.'});
 return 'https://calendar.google.com/calendar/render?'+params;
}
