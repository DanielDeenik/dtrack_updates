CREATE TABLE IF NOT EXISTS
    internal.faqs (
        faq_id serial primary key,
        priority integer,
        question text not null,
        answer text not null,
        is_published boolean not null
    );

CREATE OR REPLACE VIEW
    api.faqs
WITH
    (security_invoker = on) AS
SELECT
    faq_id as id,
    priority,
    question,
    answer,
    is_published
FROM
    internal.faqs;

ALTER TABLE internal.faqs ENABLE ROW LEVEL SECURITY;

-- TODO: Check these policies directly, as they are obscured away from user in frontend
CREATE POLICY faqs_policy ON internal.faqs USING (is_published IS TRUE)
WITH
    CHECK (pg_has_role('power', 'MEMBER'));

CREATE POLICY delete_faqs_policy ON internal.faqs FOR DELETE USING (pg_has_role('power', 'MEMBER'));
