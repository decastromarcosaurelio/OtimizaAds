/*
  # Função para verificar uso do recurso de análise de funil

  1. Nova função
    - `check_funnel_analysis_usage` - verifica se o usuário pode usar o recurso
    - Retorna informações sobre uso atual e limite do plano
  
  2. Segurança
    - Função utiliza verificação de autenticação
    - Políticas RLS aplicadas automaticamente
*/

CREATE OR REPLACE FUNCTION check_funnel_analysis_usage(user_uuid uuid)
RETURNS TABLE (
  can_use boolean,
  current_usage integer,
  limit_value integer
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_plan_id uuid;
  plan_features jsonb;
  funnel_limit integer := 0;
  current_period_start timestamp with time zone;
  current_period_end timestamp with time zone;
  usage_count integer := 0;
BEGIN
  -- Verificar se o usuário está autenticado
  IF user_uuid IS NULL OR user_uuid != auth.uid() THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  -- Obter plano atual do usuário
  SELECT us.plan_id INTO user_plan_id
  FROM user_subscriptions us
  WHERE us.user_id = user_uuid 
    AND us.status = 'active';

  -- Se não tem plano ativo, verificar se é admin
  IF user_plan_id IS NULL THEN
    -- Verificar se é admin (admins têm acesso ilimitado)
    IF is_admin(user_uuid) THEN
      RETURN QUERY SELECT true, 0, -1; -- -1 indica ilimitado
      RETURN;
    ELSE
      -- Usuário sem plano ativo
      RETURN QUERY SELECT false, 0, 0;
      RETURN;
    END IF;
  END IF;

  -- Obter configurações do plano
  SELECT sp.features INTO plan_features
  FROM subscription_plans sp
  WHERE sp.id = user_plan_id;

  -- Extrair limite de análises de funil
  IF plan_features ? 'funnel_analysis_limit' THEN
    funnel_limit := (plan_features->>'funnel_analysis_limit')::integer;
  END IF;

  -- Se limite é 0, usuário não tem acesso
  IF funnel_limit = 0 THEN
    RETURN QUERY SELECT false, 0, 0;
    RETURN;
  END IF;

  -- Se limite é -1, acesso ilimitado
  IF funnel_limit = -1 THEN
    RETURN QUERY SELECT true, 0, -1;
    RETURN;
  END IF;

  -- Calcular período atual (mês atual)
  current_period_start := date_trunc('month', now());
  current_period_end := (date_trunc('month', now()) + interval '1 month' - interval '1 second');

  -- Obter uso atual no período
  SELECT COALESCE(ut.count, 0) INTO usage_count
  FROM usage_tracking ut
  WHERE ut.user_id = user_uuid 
    AND ut.feature_type = 'funnel_analysis'
    AND ut.period_start = current_period_start;

  -- Verificar se pode usar (não atingiu o limite)
  RETURN QUERY SELECT 
    (usage_count < funnel_limit),
    usage_count,
    funnel_limit;
END;
$$;

-- Permitir que usuários autenticados executem a função
GRANT EXECUTE ON FUNCTION check_funnel_analysis_usage(uuid) TO authenticated;