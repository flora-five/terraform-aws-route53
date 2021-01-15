provider "aws" {
  region = "eu-west-1"
}

module "delegation_sets" {
  source = "../../modules/delegation_sets"

  delegation_sets = {
    "dset_app.terraform-aws-modules-example.com" = {
      reference_name = "app.terraform-aws-modules-example.com"
    }
  }
}

module "zones" {
  source = "../../modules/zones"

  zones = {
    "terraform-aws-modules-example.com" = {
      comment = "terraform-aws-modules-example.com (production)"
      tags = {
        Name = "terraform-aws-modules-example.com"
      }
    }

    "app.terraform-aws-modules-example.com" = {
      comment           = "app.terraform-aws-modules-example.com"
      delegation_set_id = module.delegation_sets.this_route53_delegation_set_id["dset_app.terraform-aws-modules-example.com"]
      tags = {
        Name = "app.terraform-aws-modules-example.com"
      }
    }

    "private-vpc.terraform-aws-modules-example.com" = {
      comment = "private-vpc.terraform-aws-modules-example.com"
      vpc = {
        vpc_id = module.vpc.vpc_id
      }
      tags = {
        Name = "private-vpc.terraform-aws-modules-example.com"
      }
    }
  }

  depends_on = [module.delegation_sets]
}

module "records" {
  source = "../../modules/records"

  zone_name = keys(module.zones.this_route53_zone_zone_id)[0]
  #  zone_id = module.zones.this_route53_zone_zone_id["terraform-aws-modules-example.com"]

  records = [
    {
      name = ""
      type = "A"
      ttl  = 3600
      records = [
        "10.10.10.10",
      ]
    },
    {
      name = "s3-bucket"
      type = "A"
      alias = {
        name    = module.s3_bucket.this_s3_bucket_website_domain
        zone_id = module.s3_bucket.this_s3_bucket_hosted_zone_id
      }
    },
    {
      name = "cloudfront"
      type = "A"
      alias = {
        name    = module.cloudfront.this_cloudfront_distribution_domain_name
        zone_id = module.cloudfront.this_cloudfront_distribution_hosted_zone_id
      }
    },
    {
      name           = "test"
      type           = "CNAME"
      ttl            = "5"
      records        = ["test.example.com."]
      set_identifier = "test-primary"
      weighted_routing_policy = {
        weight = 90
      }
    },
    {
      name           = "test"
      type           = "CNAME"
      ttl            = "5"
      records        = ["test2.example.com."]
      set_identifier = "test-secondary"
      weighted_routing_policy = {
        weight = 10
      }
    }
  ]

  depends_on = [module.zones]
}

module "disabled_records" {
  source = "../../modules/records"

  create = false
}

#########
# Extras - should be created in advance
#########

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket_prefix = "s3-bucket-"
  force_destroy = true

  website = {
    index_document = "index.html"
  }
}

module "cloudfront" {
  source = "terraform-aws-modules/cloudfront/aws"

  enabled             = true
  wait_for_deployment = false

  origin = {
    s3_bucket = {
      domain_name = module.s3_bucket.this_s3_bucket_bucket_regional_domain_name
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3_bucket"
    viewer_protocol_policy = "allow-all"
  }

  viewer_certificate = {
    cloudfront_default_certificate = true
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc-for-private-route53-zone"
  cidr = "10.0.0.0/16"
}
