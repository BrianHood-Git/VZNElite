-- Approved members may view player avatars, never other families' account avatars.
create policy roster_photo_member_read on storage.objects for select to authenticated using(
 bucket_id='team-photos' and
 exists(select 1 from public.team_memberships where user_id=(select auth.uid())) and
 exists(select 1 from public.team_players p where name='players/'||p.id::text||'/avatar.jpg')
);
