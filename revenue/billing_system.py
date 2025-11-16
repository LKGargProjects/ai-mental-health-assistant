"""
Enterprise Revenue & Billing System
Supports subscriptions, insurance billing, corporate plans, and usage-based pricing
"""

import stripe
import json
from typing import Dict, List, Optional, Tuple, Any
from datetime import datetime, timedelta
from decimal import Decimal
from enum import Enum
from dataclasses import dataclass
import hashlib
import hmac


class BillingPlan(Enum):
    """Available billing plans"""
    FREE = ("free", 0, "Basic support with ads")
    BASIC = ("basic", 9.99, "Unlimited chat, mood tracking")
    PREMIUM = ("premium", 29.99, "All features + priority support")
    CLINICAL = ("clinical", 99.99, "Clinical features + provider dashboard")
    ENTERPRISE = ("enterprise", 0, "Custom pricing for organizations")
    INSURANCE = ("insurance", 0, "Covered by insurance provider")
    
    def __init__(self, code: str, price: float, description: str):
        self.code = code
        self.monthly_price = price
        self.description = description


@dataclass
class InsuranceClaim:
    """Insurance claim data model"""
    claim_id: str
    patient_id: str
    provider_npi: str
    cpt_codes: List[str]
    icd10_codes: List[str]
    date_of_service: datetime
    amount_billed: Decimal
    amount_allowed: Decimal
    amount_paid: Decimal
    status: str
    payer_id: str
    

class RevenueOptimizer:
    """Maximize revenue through intelligent pricing and billing"""
    
    # CPT Codes for mental health services
    CPT_CODES = {
        '90791': {'desc': 'Psychiatric diagnostic evaluation', 'rate': 250.00},
        '90834': {'desc': 'Psychotherapy 45 minutes', 'rate': 150.00},
        '90837': {'desc': 'Psychotherapy 60 minutes', 'rate': 200.00},
        '90839': {'desc': 'Crisis psychotherapy 60 min', 'rate': 300.00},
        '90840': {'desc': 'Crisis psychotherapy add 30 min', 'rate': 150.00},
        '99354': {'desc': 'Prolonged service first hour', 'rate': 175.00},
        'H0031': {'desc': 'Mental health assessment', 'rate': 125.00},
        'H0032': {'desc': 'Mental health treatment plan', 'rate': 100.00},
    }
    
    # ICD-10 Codes for mental health conditions
    ICD10_CODES = {
        'F32.0': 'Major depressive disorder, single episode, mild',
        'F32.1': 'Major depressive disorder, single episode, moderate',
        'F32.2': 'Major depressive disorder, single episode, severe',
        'F41.0': 'Panic disorder',
        'F41.1': 'Generalized anxiety disorder',
        'F43.1': 'Post-traumatic stress disorder',
        'F43.2': 'Adjustment disorders',
        'Z73.3': 'Stress, not elsewhere classified',
    }
    
    # Insurance payers and reimbursement rates
    INSURANCE_PAYERS = {
        'BCBS': {'name': 'Blue Cross Blue Shield', 'rate_multiplier': 0.80},
        'UHC': {'name': 'UnitedHealthcare', 'rate_multiplier': 0.75},
        'ANTHEM': {'name': 'Anthem', 'rate_multiplier': 0.78},
        'CIGNA': {'name': 'Cigna', 'rate_multiplier': 0.77},
        'AETNA': {'name': 'Aetna', 'rate_multiplier': 0.76},
        'MEDICARE': {'name': 'Medicare', 'rate_multiplier': 0.65},
        'MEDICAID': {'name': 'Medicaid', 'rate_multiplier': 0.55},
    }
    
    def __init__(self, stripe_key: Optional[str] = None):
        """Initialize revenue system"""
        if stripe_key:
            stripe.api_key = stripe_key
        
        self.revenue_metrics = {
            'mrr': 0,  # Monthly Recurring Revenue
            'arr': 0,  # Annual Recurring Revenue
            'ltv': 0,  # Lifetime Value
            'cac': 0,  # Customer Acquisition Cost
            'churn_rate': 0,
            'arpu': 0,  # Average Revenue Per User
        }
        
        self.pricing_experiments = {}
        self.insurance_claims = []
        
    def calculate_optimal_pricing(self, 
                                 user_segment: str,
                                 usage_data: Dict,
                                 market_data: Dict) -> Dict:
        """Calculate optimal pricing using price elasticity"""
        
        # Base pricing by segment
        segment_multipliers = {
            'student': 0.5,
            'individual': 1.0,
            'family': 1.5,
            'professional': 2.0,
            'enterprise': 5.0,
        }
        
        base_price = 29.99
        segment_price = base_price * segment_multipliers.get(user_segment, 1.0)
        
        # Adjust for usage patterns
        usage_score = self._calculate_usage_score(usage_data)
        if usage_score > 0.8:  # Heavy user
            segment_price *= 1.2
        elif usage_score < 0.3:  # Light user
            segment_price *= 0.8
            
        # Market competition adjustment
        competitor_avg = market_data.get('competitor_avg_price', 30)
        if segment_price > competitor_avg * 1.3:
            segment_price = competitor_avg * 1.15  # Stay competitive
            
        # Value-based pricing adjustments
        outcome_score = self._calculate_outcome_score(usage_data)
        if outcome_score > 0.85:  # High value delivered
            segment_price *= 1.1
            
        # Price points for A/B testing
        price_points = {
            'control': round(segment_price, 2),
            'variant_a': round(segment_price * 0.9, 2),
            'variant_b': round(segment_price * 1.1, 2),
            'variant_c': round(segment_price * 1.2, 2),
        }
        
        return {
            'recommended_price': round(segment_price, 2),
            'price_points': price_points,
            'confidence': 0.85,
            'expected_conversion': self._estimate_conversion(segment_price),
            'expected_ltv': self._calculate_ltv(segment_price, user_segment),
        }
        
    def _calculate_usage_score(self, usage_data: Dict) -> float:
        """Calculate usage intensity score"""
        sessions_per_week = usage_data.get('sessions_per_week', 0)
        messages_per_session = usage_data.get('messages_per_session', 0)
        features_used = usage_data.get('features_used', [])
        
        # Normalize metrics
        session_score = min(sessions_per_week / 7, 1.0)
        message_score = min(messages_per_session / 20, 1.0)
        feature_score = len(features_used) / 10
        
        return (session_score * 0.4 + message_score * 0.3 + feature_score * 0.3)
        
    def _calculate_outcome_score(self, usage_data: Dict) -> float:
        """Calculate clinical outcome score"""
        mood_improvement = usage_data.get('mood_improvement', 0)
        crisis_prevented = usage_data.get('crisis_events_prevented', 0)
        engagement_streak = usage_data.get('engagement_days', 0)
        
        score = 0.0
        
        # Mood improvement (PHQ-9 reduction)
        if mood_improvement > 5:
            score += 0.4
        elif mood_improvement > 2:
            score += 0.2
            
        # Crisis prevention
        score += min(crisis_prevented * 0.2, 0.3)
        
        # Engagement
        if engagement_streak > 30:
            score += 0.3
        elif engagement_streak > 7:
            score += 0.15
            
        return min(score, 1.0)
        
    def _estimate_conversion(self, price: float) -> float:
        """Estimate conversion rate at price point"""
        # Price elasticity curve (empirical)
        if price <= 9.99:
            return 0.65
        elif price <= 19.99:
            return 0.45
        elif price <= 29.99:
            return 0.30
        elif price <= 49.99:
            return 0.15
        else:
            return 0.08
            
    def _calculate_ltv(self, price: float, segment: str) -> float:
        """Calculate customer lifetime value"""
        # Average retention by segment (months)
        retention = {
            'student': 4,
            'individual': 8,
            'family': 12,
            'professional': 18,
            'enterprise': 36,
        }
        
        avg_months = retention.get(segment, 6)
        churn_rate = 1 / avg_months
        
        # Simple LTV calculation
        ltv = price * avg_months
        
        # Adjust for upsell potential
        upsell_probability = 0.15
        upsell_value = price * 0.5
        ltv += (upsell_probability * upsell_value * avg_months)
        
        return round(ltv, 2)
        
    def process_insurance_claim(self,
                               session_data: Dict,
                               provider_npi: str,
                               payer_id: str) -> InsuranceClaim:
        """Process insurance claim for session"""
        
        # Determine appropriate CPT codes
        cpt_codes = []
        if session_data.get('is_initial'):
            cpt_codes.append('90791')  # Initial assessment
        else:
            duration = session_data.get('duration_minutes', 45)
            if duration <= 30:
                cpt_codes.append('90834')  # 45 min therapy
            else:
                cpt_codes.append('90837')  # 60 min therapy
                
        # Add crisis codes if applicable
        if session_data.get('crisis_intervention'):
            cpt_codes.append('90839')
            
        # Determine ICD-10 codes from assessment
        icd_codes = self._determine_diagnosis_codes(session_data)
        
        # Calculate billing amount
        base_amount = sum(self.CPT_CODES[code]['rate'] for code in cpt_codes)
        
        # Apply payer rate
        payer_rate = self.INSURANCE_PAYERS[payer_id]['rate_multiplier']
        allowed_amount = base_amount * payer_rate
        
        # Create claim
        claim = InsuranceClaim(
            claim_id=self._generate_claim_id(),
            patient_id=session_data['patient_id'],
            provider_npi=provider_npi,
            cpt_codes=cpt_codes,
            icd10_codes=icd_codes,
            date_of_service=datetime.utcnow(),
            amount_billed=Decimal(str(base_amount)),
            amount_allowed=Decimal(str(allowed_amount)),
            amount_paid=Decimal('0'),  # Pending
            status='SUBMITTED',
            payer_id=payer_id
        )
        
        self.insurance_claims.append(claim)
        return claim
        
    def _determine_diagnosis_codes(self, session_data: Dict) -> List[str]:
        """Determine appropriate ICD-10 codes"""
        codes = []
        
        # Based on PHQ-9 score
        phq9_score = session_data.get('phq9_score', 0)
        if phq9_score >= 20:
            codes.append('F32.2')  # Severe depression
        elif phq9_score >= 15:
            codes.append('F32.1')  # Moderate depression
        elif phq9_score >= 10:
            codes.append('F32.0')  # Mild depression
            
        # Based on GAD-7 score
        gad7_score = session_data.get('gad7_score', 0)
        if gad7_score >= 10:
            codes.append('F41.1')  # Generalized anxiety
            
        # Default if no specific diagnosis
        if not codes:
            codes.append('Z73.3')  # Stress
            
        return codes
        
    def _generate_claim_id(self) -> str:
        """Generate unique claim ID"""
        timestamp = datetime.utcnow().strftime('%Y%m%d%H%M%S')
        random_suffix = hashlib.sha256(str(datetime.utcnow()).encode()).hexdigest()[:6]
        return f"CLM{timestamp}{random_suffix}"
        
    def create_subscription(self, 
                          user_id: str,
                          plan: BillingPlan,
                          payment_method: str) -> Dict:
        """Create subscription with Stripe"""
        try:
            # Create or get customer
            customer = stripe.Customer.create(
                metadata={'user_id': user_id}
            )
            
            # Create subscription
            subscription = stripe.Subscription.create(
                customer=customer.id,
                items=[{
                    'price': self._get_stripe_price_id(plan),
                }],
                payment_method=payment_method,
                payment_behavior='default_incomplete',
                expand=['latest_invoice.payment_intent']
            )
            
            return {
                'subscription_id': subscription.id,
                'status': subscription.status,
                'client_secret': subscription.latest_invoice.payment_intent.client_secret,
            }
            
        except stripe.error.StripeError as e:
            return {'error': str(e)}
            
    def _get_stripe_price_id(self, plan: BillingPlan) -> str:
        """Get Stripe price ID for plan"""
        # These would be created in Stripe dashboard
        price_ids = {
            BillingPlan.BASIC: 'price_basic_monthly',
            BillingPlan.PREMIUM: 'price_premium_monthly',
            BillingPlan.CLINICAL: 'price_clinical_monthly',
        }
        return price_ids.get(plan, 'price_basic_monthly')
        
    def calculate_revenue_metrics(self, time_period: str = 'monthly') -> Dict:
        """Calculate key revenue metrics"""
        
        # This would query actual subscription data
        active_subscriptions = self._get_active_subscriptions()
        
        # MRR calculation
        mrr = sum(sub['monthly_price'] for sub in active_subscriptions)
        
        # ARR projection
        arr = mrr * 12
        
        # Churn rate
        churned_last_month = self._get_churned_subscriptions()
        churn_rate = len(churned_last_month) / max(len(active_subscriptions), 1)
        
        # ARPU
        arpu = mrr / max(len(active_subscriptions), 1)
        
        # CAC (Customer Acquisition Cost)
        marketing_spend = self._get_marketing_spend()
        new_customers = self._get_new_customers()
        cac = marketing_spend / max(new_customers, 1)
        
        # LTV
        avg_customer_lifetime = 1 / max(churn_rate, 0.01)  # months
        ltv = arpu * avg_customer_lifetime
        
        return {
            'mrr': round(mrr, 2),
            'arr': round(arr, 2),
            'churn_rate': round(churn_rate * 100, 2),
            'arpu': round(arpu, 2),
            'cac': round(cac, 2),
            'ltv': round(ltv, 2),
            'ltv_cac_ratio': round(ltv / max(cac, 1), 2),
            'active_subscriptions': len(active_subscriptions),
            'growth_rate': self._calculate_growth_rate(),
        }
        
    def _get_active_subscriptions(self) -> List[Dict]:
        """Get active subscriptions (mock)"""
        # This would query database
        return []
        
    def _get_churned_subscriptions(self) -> List[Dict]:
        """Get churned subscriptions (mock)"""
        return []
        
    def _get_marketing_spend(self) -> float:
        """Get marketing spend (mock)"""
        return 5000.0
        
    def _get_new_customers(self) -> int:
        """Get new customers count (mock)"""
        return 100
        
    def _calculate_growth_rate(self) -> float:
        """Calculate month-over-month growth"""
        # This would compare MRR month over month
        return 15.0  # 15% growth
        
    def run_pricing_experiment(self, 
                              experiment_name: str,
                              variants: List[Dict],
                              sample_size: int) -> Dict:
        """Run A/B test on pricing"""
        
        experiment = {
            'name': experiment_name,
            'start_date': datetime.utcnow(),
            'variants': variants,
            'sample_size': sample_size,
            'status': 'RUNNING',
            'results': {}
        }
        
        self.pricing_experiments[experiment_name] = experiment
        
        # This would actually split traffic and track conversions
        return {
            'experiment_id': experiment_name,
            'status': 'STARTED',
            'estimated_duration_days': self._estimate_experiment_duration(sample_size),
        }
        
    def _estimate_experiment_duration(self, sample_size: int) -> int:
        """Estimate how long experiment needs to run"""
        daily_traffic = 1000  # Estimated daily visitors
        conversion_rate = 0.03  # 3% baseline
        
        daily_conversions = daily_traffic * conversion_rate
        days_needed = sample_size / daily_conversions
        
        return max(int(days_needed), 7)  # Minimum 7 days
