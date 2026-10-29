using Pkg
Pkg.activate(@__DIR__)

using DecisionTree, JLD2, CategoricalArrays, Random

"""
Recursively strip `Leaf.values` (which stores all training labels that fell into each leaf)
and convert `CategoricalValue` labels to plain `String` so JLD2 does not serialize
millions of `CategoricalPool` references and training vectors.
"""
function strip_node(node::DecisionTree.Node{S, T}) where {S, T}
    return DecisionTree.Node{S, String}(
        node.featid,
        node.featval,
        strip_node(node.left),
        strip_node(node.right)
    )
end

function strip_node(leaf::DecisionTree.Leaf{T}) where {T}
    return DecisionTree.Leaf{String}(
        String(leaf.majority),
        String[]
    )
end

function strip_ensemble(ens::DecisionTree.Ensemble{S, T}) where {S, T}
    new_trees = Vector{Union{DecisionTree.Leaf{String}, DecisionTree.Node{S, String}}}(undef, length(ens.trees))
    for i in eachindex(ens.trees)
        new_trees[i] = strip_node(ens.trees[i])
    end
    return DecisionTree.Ensemble{S, String}(new_trees, ens.n_feat, ens.featim)
end

function build_fast_rf(orig_model::DecisionTree.RandomForestClassifier)
    new_ens = strip_ensemble(orig_model.ensemble)
    new_classes = String.(orig_model.classes)
    return DecisionTree.RandomForestClassifier(;
        n_subfeatures = orig_model.n_subfeatures,
        n_trees = orig_model.n_trees,
        partial_sampling = orig_model.partial_sampling,
        max_depth = orig_model.max_depth,
        min_samples_leaf = orig_model.min_samples_leaf,
        min_samples_split = orig_model.min_samples_split,
        min_purity_increase = orig_model.min_purity_increase,
        rng = orig_model.rng,
        impurity_importance = orig_model.impurity_importance,
        ensemble = new_ens,
        classes = new_classes
    )
end

# Self-test on synthetic model before touching multi-GB models
let
    println("Running self-test on synthetic RandomForestClassifier...")
    X = randn(100, 6)
    y = categorical(rand(["Supine", "Prone", "Sitting"], 100))
    m = RandomForestClassifier(n_trees=5)
    DecisionTree.fit!(m, X, y)
    m_fast = build_fast_rf(m)
    @assert String.(DecisionTree.predict(m, X)) == DecisionTree.predict(m_fast, X)
    println("  Self-test passed!")
end

function optimize_rf_model(input_path::String, output_path::String)
    println("====================================================")
    println("Loading original model: $input_path")
    t_load_orig = @elapsed orig_model = load_object(input_path)
    orig_size_mb = round(filesize(input_path) / (1024^2), digits=2)
    println("  Loaded in $(round(t_load_orig, digits=2))s (file size: $(orig_size_mb) MB)")

    println("Stripping training leaf vectors and CategoricalPool references...")
    fast_model = build_fast_rf(orig_model)

    println("Saving optimized model: $output_path")
    t_save = @elapsed save_object(output_path, fast_model)
    new_size_mb = round(filesize(output_path) / (1024^2), digits=2)
    println("  Saved in $(round(t_save, digits=2))s (new file size: $(new_size_mb) MB)")

    println("Testing reload speed of $output_path...")
    t_load_fast = @elapsed reloaded_model = load_object(output_path)
    println("  Reloaded in $(round(t_load_fast, digits=3))s ($(round(t_load_orig / t_load_fast, digits=1))x faster, $(round(orig_size_mb / new_size_mb, digits=1))x smaller)")

    # Verify predictions are 100% identical on random test features
    n_features = orig_model.ensemble.n_feat
    rng = MersenneTwister(42)
    X_test = randn(rng, 2000, n_features)
    preds_orig = String.(DecisionTree.predict(orig_model, X_test))
    preds_fast = DecisionTree.predict(reloaded_model, X_test)
    @assert preds_orig == preds_fast "Mismatch between original and fast model predictions!"
    println("  Verified: 100% identical predictions across 2,000 test rows (n_feat = $n_features).")

    # Free memory before next model
    orig_model = nothing
    fast_model = nothing
    reloaded_model = nothing
    GC.gc()
end

const MODELS = [
    ("group_model_TDCP.jld2", "group_model_TDCP_fast.jld2"),
    ("group_model_restraint_GA.jld2", "group_model_restraint_GA_fast.jld2"),
    ("group_model_parent.jld2", "group_model_parent_fast.jld2")
]

for (in_file, out_file) in MODELS
    if isfile(in_file)
        optimize_rf_model(in_file, out_file)
    else
        @warn "File not found, skipping: $in_file"
    end
end

println("====================================================")
println("All models optimized successfully!")
