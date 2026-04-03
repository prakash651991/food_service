CREATE POLICY "Users can update their own subs" ON subscriptions
  FOR UPDATE USING (auth.uid() = customer_id);
